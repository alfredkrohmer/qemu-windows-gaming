require 'mqtt'

# Listen on MQTT requests to detach / attach the given USB devices
class MqttListener
  def initialize(qmp, devices, broker, topic)
    @qmp     = qmp
    @devices = devices
    @conn    = MQTT::Client.connect(broker)
    @topic   = topic
  end

  def run
    # wait for commands to attach / detach
    @conn.get(@topic) do |_, message|
      case message
      when '0'
        @devices.keys.each(&@qmp.method(:del_usb))
      when '1'
        @devices.each(&@qmp.method(:add_usb))
      end
    end
  end
end
