module Hadupils::Extensions
  # Tools for managing hive initialization files ("hiverc").
  module HiveRC
    module HiveOpt
      def hive_opts
        ['-i', path]
      end
    end

    # Wraps an extant hive initialization file, and providing
    # an interface compatible with the critical parts of the
    # Dynamic sibling class so they may be used interchangeably
    # by runners when determining hive options.
    class Static
      attr_reader :path

      include HiveOpt

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

      include HiveOpt
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
        @file.write(lines.join("\n") + "\n")
        @file.flush
      end
    end
  end

  class EvalProxy
    def initialize(scope)
      @scope = scope
    end

    def assets(&block)
      @scope.instance_eval do
        @assets_block = block
      end
    end

    def hiverc(&block)
      @scope.instance_eval do
        @hiverc_block = block
      end
    end
  end

  class Base
    attr_reader :assets, :path

    def initialize(directory, &block)
      if block_given?
        EvalProxy.new(self).instance_eval &block
      end
      @path = ::File.expand_path(directory)
      @assets = merge_assets(self.class.gather_assets(@path))
    end

    def merge_assets(assets)
      return @assets_block.call(assets) if @assets_block
      assets
    end

    def hivercs
      []
    end

    def self.gather_assets(directory)
      if not directory.nil?
        Hadupils::Assets.assets_in(directory)
      else
        []
      end
    end
  end

  class Flat < Base
    def hivercs
      @hiverc ||= assemble_hiverc
      [@hiverc]
    end

    def assemble_hiverc
      assets = @assets
      if @hiverc_block
        assets = @hiverc_block.call(assets.dup)
      end
      hiverc = Hadupils::Extensions::HiveRC::Dynamic.new
      hiverc.write(assets)
      hiverc
    end
  end

  class Static < Base
    def self.gather_assets(path)
      []
    end

    def hiverc_path
      ::File.join(path, 'hiverc')
    end

    def hiverc?
      ::File.file? hiverc_path
    end

    def hivercs
      r = []
      r << Hadupils::Extensions::HiveRC::Static.new(hiverc_path) if hiverc?
      r
    end
  end
end
