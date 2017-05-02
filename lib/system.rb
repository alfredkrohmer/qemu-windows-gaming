require 'singleton'

class SystemManager
  include Singleton

  attr_accessor :qmp_commands, :qmp_events, :usb, :mon, :mqtt

  def initialize
    @in_host = true
  end

  def switch_to_host
    @in_host = true
    @mqtt.publish false
    @mon.set_host true
    @mon.set_guest false
    @usb.detach
  end

  def switch_to_guest
    @in_host = false 
    @mqtt.publish true
    @usb.attach
    @qmp_commands.system_wakeup if @qmp_events.suspended
    @mon.set_guest true
    @mon.set_host false
  end

  def switch
    if @in_host
      switch_to_guest
    else
      switch_to_host
    end
  end

  def shutdown
    unless @qmp_events.shutdown
      @qmp_commands.system_powerdown
      @qmp_events.thread.join
    end

    switch_to_host
  end
end
