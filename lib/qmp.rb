require 'json'
require 'socket'

# Communicate with QEMU over the QMP (QEMU Machine Protocol)
class Qmp
  attr_reader :thread, :shutdown, :suspended

  def initialize(socket)
    @s = UNIXSocket.new socket
    @s.readline
    qmp_capabilities

    @shutdown  = false
    @suspended = false
  end

  # execute the given method in QEMU
  def method_missing(method, args = nil)
    hash = { execute: method.to_s }
    hash[:arguments] = args unless args.nil?
    puts hash.to_json
    @s.puts(hash.to_json)
    resp = @s.readline
    puts resp.inspect
    JSON.parse(resp)['return']
  end
  alias :execute :method_missing

  # event processing loop
  def run
    loop do
      event = JSON.parse(@s.readline)
      puts event.inspect
      name  = event['event']
      data  = event['data']

      case name
      when 'SUSPEND'
        puts 'VM suspended'
        SystemManager.instance.switch_to_host
        @suspended = true
      when 'RESUME'
        puts 'VM resumed'
        @suspended = false
      when 'SHUTDOWN'
        puts 'VM shut down'
        @shutdown = true
        Thread.exit
      end
    end
  end
end
