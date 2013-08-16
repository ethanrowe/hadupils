module Hadupils::Extensions
  # Tools for managing hive initialization files ("hiverc").
  module HiveRC
    # Wraps an extant hive initialization file, and providing
    # an interface compatible with the critical parts of the
    # Dynamic sibling class so they may be used interchangeably
    # by runners when determining hive options.
    class Static
      attr_reader :path

      # Given a path, expands it ti
      def initialize(path)
        @path = ::File.expand_path(path)
      end

      def close
      end
    end

    # Manages dynamic hive initialization files, assembling a temporary file
    # and understanding how to write assets/lines into the initialization file for
    # use with hive's -i option.
    class Dynamic
      attr_reader :file

      require 'tempfile'

      # This will allow us to change what handles the dynamic files.
      def self.file_handler=(handler)
        @file_handler = handler
      end

      # The class to use for creating the files; defaults to ::Tempfile
      def self.file_handler
        @file_handler || ::Tempfile
      end

      # Sets up a wrapped file, using the class' file_handler, 
      def initialize
        @file = self.class.file_handler.new('hadupils-hiverc')
      end

      def path
        ::File.expand_path @file.path
      end

      def close
        @file.close
      end

      # Writes the items to the file, using #hiverc_command on each item that
      # responds to it (Hadupils::Assets::* instances) and #to_s on the rest.
      # Separates lines by newline, and provides a trailing newline.  However,
      # the items are responsible for ensuring the proper terminating semicolon.
      # The writes are flushed to the underlying file immediately afterward.
      def write(items)
        lines = items.collect do |item|
          if item.respond_to? :hiverc_command
            item.hiverc_command
          else
            item.to_s
          end
        end
        @file.write(lines.join('\n') + '\n')
        @file.flush
      end
    end
  end

  class Base
    attr_reader :assets, :path

    def initialize(directory)
      @path = ::File.expand_path(directory)
      @assets = self.class.gather_assets(@path)
    end

    def hivercs
      []
    end

    def self.gather_assets(directory)
      Hadupils::Assets.assets_in(directory)
    end
  end
end
