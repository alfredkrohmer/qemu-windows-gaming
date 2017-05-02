class CgroupManager
  def initialize(cgroup_path = '/sys/fs/cgroup', cgroup_name = 'system', system_core = 0)
    @cgroup_path = File.join(cgroup_path, 'cpuset')
    @cgroup_name = File.join(@cgroup_path, cgroup_name)

    # create cgroup for all threads in the system
    Dir.mkdir(File.join(@cgroup_name)) rescue Errno::EEXIST

    # pin all threads in the system to their designated core
    File.write(File.join(@cgroup_name, 'cpuset.cpus'), Array(system_core).map(&:to_s).join(','))
    File.write(File.join(@cgroup_name, 'cpuset.mems'), '0')

    # move all tasks to that cgroup
    File.read(File.join(@cgroup_path, 'tasks')).chomp.split("\n").each do |pid|
      # this is a kernel thread, don't touch it
      next if pid == '2' or File.read("/proc/#{pid}/stat").split(' ')[3] == '2'

      # don't move ourselves
      next if pid == $$.to_s

      File.write(File.join(@cgroup_name, 'tasks'), pid) rescue Errno::ESRCH
    end

    at_exit do
      reset
    end
  end

  def reset
    File.read(File.join(@cgroup_name, 'tasks')).chomp.split("\n").each do |pid|
      File.write(File.join(@cgroup_path, 'tasks'), pid) rescue Errno::ESRCH
    end

    Dir.rmdir(File.join(@cgroup_name))
  end
end
