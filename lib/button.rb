class ButtonManager
  def initialize(device)
    @dev = File.open(device, 'rb')
  end

  def run
    Thread.start do
      loop do
        _, _, type, code, value = @dev.sysread(24).unpack('QQSSL')
        next unless type == 1 && code == 116 && value == 1 # power button pressed
  
        SystemManager.instance.switch
      end
    end
  end
end
