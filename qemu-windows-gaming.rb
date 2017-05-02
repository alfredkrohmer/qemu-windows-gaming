#!/usr/bin/ruby

require 'yaml'
require 'shellwords'

require_relative 'lib/system'
require_relative 'lib/qmp'
require_relative 'lib/cgroup'
require_relative 'lib/pci'
require_relative 'lib/hugepages'
require_relative 'lib/usb'
require_relative 'lib/monitor'
require_relative 'lib/button'
require_relative 'lib/mqtt'

Thread.abort_on_exception = true

config = YAML.load(File.read(ARGV[0] || 'config.yml'))

PciManager.new(config['pci_devices'].values)
HugepagesManager.new(config['memory'])
CgroupManager.new '/sys/fs/cgroup', 'system', config['cpu']['system']

# build whole QEMU launch command
cmd = [
  %w(taskset -a -c), Array(config['cpu']['qemu']).map(&:to_s).join(','),

  'qemu-system-x86_64',

  '-rtc', 'base=localtime,clock=rt',

  # QMP remote control
  %w(cmd event misc).map do |type|
    ['-qmp', "unix:/run/qmp-#{type}.sock,server,nowait"]
  end,

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

Array(config['pre_action']).each do |action|
  puts "pre_action> #{action}"
  system action
end

puts "Starting Qemu: #{cmd.inspect}"
pid = spawn({
  'QEMU_AUDIO_DRV' => 'pa',
  'QEMU_PA_SINK'   => config['audio_sink'],
  'QEMU_PA_SAMPLES' => '128',
  'QEMU_AUDIO_DAC_FIXED_SETTINGS' => '1',
  'QEMU_AUDIO_DAC_FIXED_FREQ' => '44100',
  'QEMU_AUDIO_DAC_FIXED_FMT' => 'S16',
  'QEMU_AUDIO_TIMER_PERIOD' => '2000'
}, *cmd)

# exit script when QEMU finishes
tid = Thread.start do
  exit Process.wait pid
end

sm = SystemManager.instance

sleep 1

# attach to QEMU control & events socket
qmp = sm.qmp_commands = Qmp.new '/run/qmp-cmd.sock'
qmp.execute('query-cpus').each do |info|
  `taskset -p -c #{config['cpu']['vm'][info['CPU']]} #{info['thread_id']}`
end
qmp_events = sm.qmp_events = Qmp.new('/run/qmp-event.sock')

usb = sm.usb = UsbManager.new qmp, qmp_events, config
mon = sm.mon = MonitorManager.new qmp

btn = ButtonManager.new(config['button_device'])
btn.run

mqtt = sm.mqtt = MqttManager.new(qmp, config)
mqtt.run

at_exit do
  sm.shutdown

  Array(config['post_action']).each do |action|
    puts "post_action> #{action}"
    system action
  end
end

# event loop
qmp_events.run
