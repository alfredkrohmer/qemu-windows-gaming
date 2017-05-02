# Bind the given PCI devices to the 'vfio-pci' driver.
class PciManager
  def initialize(devices)
    `modprobe vfio vfio_pci`

    devices.map do |id|
      # unbind old driver
      p = "/sys/bus/pci/devices/#{id}"
      path = "#{p}/driver"
      next [id, p, nil] unless File.exist? path

      unless (driver = File.readlink(path).split('/')[-1]) == 'vfio-pci'
        File.write "#{path}/unbind", id
      end

      [id, p, driver]
    end.each do |id, p, old_driver|
      # set driver_override to new driver
      unless File.read("#{p}/driver_override") == 'vfio-pci'
        File.write("#{p}/driver_override", 'vfio-pci')
        at_exit do
          File.write("#{p}/driver_override", '')
        end
      end

      # bind to new driver
      path = "#{p}/driver"
      if old_driver.nil? or File.readlink(path).split('/')[-1] != 'vfio-pci'
        File.write "/sys/bus/pci/drivers/vfio-pci/bind", id
        at_exit do
          File.write "#{path}/unbind", id
          File.write "/sys/bus/pci/drivers/#{old_driver}/bind", id unless old_driver.nil?
        end
      end
    end
  end
end
