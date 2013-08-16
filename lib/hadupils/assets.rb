module Hadupils::Assets
  class File
    attr_reader :name, :path

    def self.determine_name(path)
      ::File.basename(path)
    end

    def self.hiverc_type
      :FILE
    end

    def initialize(path)
      @path = path
      @name = self.class.determine_name(path)
    end

    def hidden?
      name[0] == '.'
    end

    def hiverc_command
      "ADD #{self.class.hiverc_type} #{path};"
    end
  end

  class Jar < File
    def self.hiverc_type
      :JAR
    end
  end

  class Archive < File
    def self.hiverc_type
      :ARCHIVE
    end
  end

  def self.asset_for(path)
    return Archive.new(path) if path[-7..-1] == '.tar.gz'
    return Jar.new(path) if path[-4..-1] == '.jar'
    return File.new(path)
  end

  SKIP_NAMES = ['.', '..']

  # Walks the top-level members of the stated directory and
  # yields an appropriate HadoopAsset::* instance for each.
  def self.foreach_asset_in(directory)
    path = ::File.expand_path(directory)
    ::Dir.foreach(path) do |entry|
      next if SKIP_NAMES.include? entry
      yield asset_for(::File.join(path, entry))
    end
  end
end
