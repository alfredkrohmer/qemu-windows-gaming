class HugepagesManager
  def initialize(memory)
    File.write '/proc/sys/vm/nr_hugepages', (memory / 2 + 50).to_s
    at_exit do
      File.write '/proc/sys/vm/nr_hugepages', '0'
    end
  end
end
