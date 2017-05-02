class MonitorManager
  def initialize(qmp)
    @qmp = qmp
  end

  def set_host(on)
    system "xset dpms force #{on ? 'on' : 'off'}"
  end

  def set_guest(on)
    if on
      @qmp.execute 'send-key', keys: [ type: :qcode, data: 'ctrl' ]
    else
      @qmp.system_powerdown
    end
  end
end
