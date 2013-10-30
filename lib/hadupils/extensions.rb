require 'uuid'
require 'open3'
require 'tempfile'

module Hadupils::Extensions
  # Tools for managing shell commands/output performed by the runners
  module Runners
    module Shell
      def self.command(*command_list)
        opts      = {}
        stdout    = nil
        stderr    = nil
        status    = nil

        begin
          if RUBY_VERSION < '1.9'
            Open3.popen3(*command_list) do |i, o, e|
              stdout = o.read
              stderr = e.read
            end
            status = $?
            $stdout.puts stdout unless stdout.nil? || stdout.empty? || Shell.silence_stdout?
            $stderr.puts stderr unless stderr.nil? || stderr.empty?
            stdout = nil unless capture_stdout?
            stderr = nil unless capture_stderr?
          else
            stdout_rd, stdout_wr  = IO.pipe     if capture_stdout?
            stderr_rd, stderr_wr  = IO.pipe     if capture_stderr?
            opts[:out]            = stdout_wr   if capture_stdout?
            opts[:err]            = stderr_wr   if capture_stderr?

            # NOTE: eval prevents Ruby 1.8.7 from throwing a syntax error on Ruby 1.9+ syntax
            result = eval 'Kernel.system(*command_list, opts)'
            status = result ? $? : nil
            if capture_stdout?
              stdout_wr.close
              stdout = stdout_rd.read
              stdout_rd.close
              $stdout.puts stdout unless stdout.nil? || stdout.empty? || Shell.silence_stdout?
            end
            if capture_stderr?
              stderr_wr.close
              stderr = stderr_rd.read
              stderr_rd.close
              $stderr.puts stderr unless stderr.nil? || stderr.empty?
            end
          end
          [stdout, stderr, status]
        rescue Errno::ENOENT => e
          $stderr.puts e
          [stdout, stderr, nil]
        end
      end

      def self.capture_stderr?
        @capture_stderr
      end

      def self.capture_stderr=(value)
        @capture_stderr = value
      end

      def self.capture_stdout?
        @capture_stdout || Shell.silence_stdout?
      end

      def self.capture_stdout=(value)
        @capture_stdout = value
      end

      def self.silence_stdout?
        @silence_stdout
      end

      def self.silence_stdout=(value)
        @silence_stdout = value
      end
    end
  end

  # Tools for managing tmp files in the hadoop dfs
  module Dfs
    module TmpFile
      def self.uuid
        @uuid ||= UUID.new
      end

      def self.tmp_ttl
        @tmp_ttl ||= (ENV['HADUPILS_TMP_TTL'] || '86400').to_i
      end

      def self.tmp_path
        @tmp_path ||= (ENV['HADUPILS_TMP_PATH'] || '/tmp')
      end

      def self.tmpfile_path
        @tmpfile_path ||= ::File.join(tmp_path, "hadupils-tmp-#{uuid.generate(:compact)}")
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
