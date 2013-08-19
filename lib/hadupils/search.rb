module Hadupils::Search
  # Searches for directory containing a subdirectory `name`, starting at
  # the specified `start` directory and walking upwards until it can go
  # no farther.  On first match, the absolute path to that subdirectory
  # is returned.  If not found, returns nil.
  def self.find_from_dir(name, start)
    curr = ::File.expand_path(start)
    last = nil
    while curr != last
      p = ::File.join(curr, name)
      return p if ::File.directory? p
      last = curr
      curr = ::File.dirname(curr)
    end
    nil
  end

  # Performs a `find_from_dir` starting at the present working directory.
  def self.find_from_pwd(name)
    find_from_dir(name, ::Dir.pwd)
  end
end
