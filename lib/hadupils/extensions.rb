require 'uuid'
require 'tempfile'

module Hadupils::Extensions
  # Tools for managing tmp files in the hadoop dfs
  module Dfs
    module TmpFile
      def self.uuid
        @uuid ||= UUID.new
      end

      def self.tmp_path
        @tmp_path ||= (ENV['HADUPILS_BASE_TMP_PATH'] || '/tmp')
      end

      def self.tmpfile_path
        @tmpdir_path ||= ::File.join(tmp_path, "hadupils-tmp-#{uuid.generate(:compact)}")
      end

      def self.reset_tmpfile!
        @tmpdir_path = nil
      end
    end
  end

  # Tools for managing hadoop configuration files ("hadoop.xml").
  module HadoopConf
    module HadoopOpt
      def hadoop_opts
        ['-conf', path]
      end
    end

    # Wraps an extant hadoop configuration file and provides
    # an interface compatible with the critical parts of the
    # Static sibling class so they may be used interchangeably
    # by runners when determining hadoop options.
    class Static
      attr_reader :path

      include HadoopOpt

      # Given a path, expands it ti
      def initialize(path)
        @path = ::File.expand_path(path)
      end

      def close
      end
    end
  end

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

    def hadoop_conf(&block)
      @scope.instance_eval do
        @hadoop_conf_block = block
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
      @path = ::File.expand_path(directory) unless directory.nil?
      @assets = merge_assets(self.class.gather_assets(@path))
    end

    def merge_assets(assets)
      return @assets_block.call(assets) if @assets_block
      assets
    end

    def hadoop_confs
      []
    end

    def hivercs
      []
    end

    def self.gather_assets(directory)
      if directory
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

    def default_hiverc_items
      @assets.dup
    end

    def assemble_hiverc
      assets = default_hiverc_items
      if @hiverc_block
        assets = @hiverc_block.call(assets.dup)
      end
      hiverc = Hadupils::Extensions::HiveRC::Dynamic.new
      hiverc.write(assets)
      hiverc
    end
  end

  class FlatArchivePath < Flat
    def archives_for_path_env
      @assets.find_all do |a|
        if a.kind_of? Hadupils::Assets::Archive
          begin
            Hadupils::Util.archive_has_directory?(a.path, 'bin')
          rescue
            false
          end
        else
          false
        end
      end
    end

    def default_hiverc_items
      items = super
      archs = archives_for_path_env
      if archs.length > 0
        items << self.class.assemble_path_env(archs)
      end
      items
    end

    def self.assemble_path_env(archives)
      paths = archives.collect {|a| "$(pwd)/#{ a.name }/bin" }
      "SET mapred.child.env = PATH=#{ paths.join(':') }:$PATH;"
    end
  end

  class Static < Base
    def self.gather_assets(path)
      []
    end

    def hadoop_conf_path
      ::File.join(path, 'hadoop.xml') if path
    end

    def hiverc_path
      ::File.join(path, 'hiverc') if path
    end

    def hadoop_conf?
      hadoop_conf_path ? ::File.file?(hadoop_conf_path) : false
    end

    def hiverc?
      hiverc_path ? ::File.file?(hiverc_path) : false
    end

    def hadoop_confs
      r = []
      r << Hadupils::Extensions::HadoopConf::Static.new(hadoop_conf_path) if hadoop_conf?
      r
    end

    def hivercs
      r = []
      r << Hadupils::Extensions::HiveRC::Static.new(hiverc_path) if hiverc?
      r
    end
  end
end

require 'hadupils/extensions/hive'
