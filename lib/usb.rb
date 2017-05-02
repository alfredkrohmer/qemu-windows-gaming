class UsbManager
  def initialize(qmp, qmp_events, config)
    @qmp        = qmp
    @qmp_events = qmp_events
    @config     = config
  end

  # execute pre_action and attach all configured USB devices
  def attach
    Array(@config['usb']['pre_action']).each do |action|
      puts "usb pre_action> #{action}"
      system action
    end

    @config['usb']['devices'].each do |name, id|
      puts "Adding USB device '#{name}'"
      @qmp.device_add(driver: 'usb-host', productid: id, id: name)
    end
  end

  # detach all configured USB devices and execute post_action
  def detach
    @config['usb']['devices'].keys.each do |name|
      puts "Removing USB device '#{name}'"
      @qmp.device_del(id: name)
    end unless @qmp_events.shutdown

    sleep 1

    Array(@config['usb']['post_action']).each do |action|
      puts "usb post_action> #{action}"
      system action
    end
  end
end
