# Bind the given PCI devices to the 'vfio-pci' driver.
class PciManager
  def initialize(devices)
    `modprobe vfio vfio_pci`

    devices.each do |id|
      unless File.readlink("/sys/bus/pci/devices/#{id}/driver").split('/')[-1] == 'vfio-pci'
        File.write "/sys/bus/pci/devices/#{id}/driver/unbind", id
      end
    end

    devices.each do |id|
      unless File.readlink("/sys/bus/pci/devices/#{id}/driver").split('/')[-1] == 'vfio-pci'
        File.write "/sys/bus/pci/drivers/vfio-pci/bind", id
      end
    end
  end
end
