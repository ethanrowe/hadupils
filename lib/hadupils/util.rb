module Hadupils::Util
  def self.read_archive(archive_path)
    require 'rubygems/package'
    require 'zlib'
    Zlib::GzipReader.open(archive_path) do |zlib|
      Gem::Package::TarReader.new(zlib) do |tar|
        tar.rewind
        yield tar
      end
    end
  end

  def self.archive_has_directory?(archive_path, directory)
    directory = directory + '/' unless directory.end_with?('/')
    targets = [directory[0..-2], directory]
    found = false
    read_archive(archive_path) do |arch|
      arch.each do |entry|
        found = (entry.directory? and targets.include?(entry.full_name))
        break if found
      end
    end
    found
  end
end
