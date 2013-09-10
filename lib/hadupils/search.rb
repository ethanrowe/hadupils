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

  # The directory for user-specific configuration files.
  def self.user_config
    @user_config || ::File.expand_path(::File.join('~', 'conf'))
  end

  def self.user_config=(path)
    @user_config = path
  end

  # The basename to use when looking for hadoop assets from pwd.
  def self.hadoop_assets_name
    @hadoop_assets_name || 'hadoop-ext'
  end

  # Set the basename to use when looking for hadoop assets from pwd.
  def self.hadoop_assets_name=(basename)
    @hadoop_assets_name = basename
  end

  # A search for #hadoop_assets_name from the pwd.
  # The default behavior is to look for a subdir named "hadoop-ext",
  # starting from the current working directory and walking upwards until
  # a match is found or the file system root is encountered.
  def self.hadoop_assets
    find_from_pwd(hadoop_assets_name)
  end

  # The basename to use when looking for hive extensions from pwd.
  def self.hive_extensions_name
    @hive_extensions_name || 'hive-ext'
  end

  # Set the basename to use when looking for hive assets from pwd.
  def self.hive_extensions_name=(basename)
    @hive_extensions_name = basename
  end

  # A search for #hive_extensions_name from the pwd.
  # The default behavior is to look for a subdir named +hive-ext+,
  # starting from the current working directory and walking upwards until
  # a match is found or the file system root is encountered.
  def self.hive_extensions
    find_from_pwd(hive_extensions_name)
  end
end
