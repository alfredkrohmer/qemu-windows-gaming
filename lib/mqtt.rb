require 'mqtt'

# Listen on MQTT requests to detach / attach the given USB devices
class MqttManager
  attr_accessor :devices

  def initialize(qmp, config)
    @qmp     = qmp
    @broker  = config['mqtt']['broker']
    @topic   = config['mqtt']['topic']
  end

  def publish(state)
    @self_published = true
    @conn.publish(@topic, state ? '1' : '0')
  end

  def run
    Thread.start do
      @conn = MQTT::Client.connect(@broker)
      publish true

      # wait for commands to switch to host / guest
      @conn.get(@topic) do |_, message|
        if @self_published
          puts "Self published: #{message}"
          @self_published = false
          next
        end

        puts "MQTT message: #{message}"
        case message
        when '0'
          SystemManager.instance.switch_to_host
        when '1'
          SystemManager.instance.switch_to_guest
        end
      end
    end
  end
end
