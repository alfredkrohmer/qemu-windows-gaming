require 'json'
require 'socket'

# Communicate with QEMU over the QMP (QEMU Machine Protocol)
class Qmp 
  def initialize(socket)
    @s = UNIXSocket.new socket
    @s.readline
    qmp_capabilities
  end

  def method_missing(method, args = nil)
    hash = { execute: method.to_s }
    hash[:arguments] = args unless args.nil?
    @s.puts(hash.to_json)
    JSON.parse(@s.readline)['return']
  end
  alias :execute :method_missing

  def del_usb(name)
    puts "Removing USB device '#{name}'"
    device_del(id: name)
  end

  def add_usb(name, id)
    puts "Adding USB device '#{name}'"
    device_add(driver: 'usb-host', productid: id, id: name)
  end
end
