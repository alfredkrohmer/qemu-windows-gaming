#!/usr/bin/ruby

require 'yaml'
require 'shellwords'

require_relative 'lib/qmp'
require_relative 'lib/cgroup'
require_relative 'lib/pci'
require_relative 'lib/hugepages'
require_relative 'lib/mqtt'

config = YAML.load(File.read(ARGV[0] || 'config.yml'))

pci = PciManager.new(config['pci_devices'].values)

hp = HugepagesManager.new(config['memory'])
at_exit { hp.reset }

cg = CgroupManager.new '/sys/fs/cgroup', 'system', config['cpu']['system']
at_exit { cg.reset }

cmd = [
  %w(taskset -a -c), Array(config['cpu']['qemu']).map(&:to_s).join(','),

  'qemu-system-x86_64',

  # QMP remote control
  %w(-qmp unix:/run/qmp.sock,server,nowait),

  # basic settings
  %w(-enable-kvm -M q35,accel=kvm -cpu host,kvm=off -vga none),

  # UEFI
  '-drive', "if=pflash,format=raw,readonly,file=#{ENV['HOME']}/OVMF_CODE-pure-efi.fd",
  '-drive', "if=pflash,format=raw,file=#{ENV['HOME']}/OVMF_VARS-pure-efi.fd",

  # CPU
  '-smp', "#{config['cpu']['vm'].count},sockets=1,cores=#{config['cpu']['vm'].count / (config['hyperthreading'] ? 2 : 1)},threads=#{config['hyperthreading'] ? 2 : 1}",

  # memory
  '-m', config['memory'],
  %w(-mem-path /dev/hugepages),

  # disk
  Array(config['disk']).each_with_index.map { |disk, i|
    ["-hd#{('a'.ord + i).chr}", disk]
  },

  # sound
  %w(-soundhw hda),

  # PCI devices
  %w(-device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1),
  config['pci_devices'].map { |function, id|
    str = "vfio-pci,host=#{id.to_s.split(':')[1..-1].join ':'},bus=root.1,addr=#{id.to_s.split(':')[-1]}"
    str << ',multifunction=on,x-vga=on' if function == 'vga'
    ['-device', str]
  },

  # USB
  '-usb',
].flatten.map(&:to_s)

if config['qemu_extra_flags']
  if config['qemu_extra_flags'].is_a? Array
    cmd += config['qemu_extra_flags']
  else
    cmd += Shellwords.split(config['qemu_extra_flags'])
  end
end

puts "Starting Qemu: #{cmd.inspect}"

pid = spawn({
  'QEMU_AUDIO_DRV' => 'pa',
  'QEMU_PA_SINK'   => config['audio_sink']
}, *cmd)
tid = Thread.start do
  exit Process.wait pid
end

sleep 1

qmp = Qmp.new '/run/qmp.sock'

qmp.execute('query-cpus').each do |info|
  `taskset -p -c #{config['cpu']['vm'][info['CPU']]} #{info['thread_id']}`
end

config['usb_devices'].each(&qmp.method(:add_usb))

if config['manage_monitors']
  sleep 5
  `xset dpms force off`
end

at_exit do
  qmp.system_powerdown
  Process.wait pid
end

if config['mqtt']['enable']
  mqtt = MqttListener.new(qmp, config['usb_devices'], config['mqtt']['broker'], config['mqtt']['topic'])
  mqtt.run
else
  tid.join
end

`xset dpms force on` if config['manage_monitors']
