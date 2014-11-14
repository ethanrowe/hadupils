require 'hadupils/commands/options'

module Hadupils::Commands
  def self.run(command, params=[])
    handler = handler_for command
    handler.run params
  end

  def self.normalize_command(command)
    command.to_s.downcase
  end

  def self.handler_for(command)
    @handlers and @handlers[normalize_command(command)]
  end

  def self.register_handler(command, handler)
    @handlers ||= {}
    @handlers[normalize_command(command)] = handler
  end

  class SimpleCommand
    attr_reader :params

    def initialize(params=[])
      @params = params
    end

    def self.run(params=[])
      self.new(params).run
    end

    def successful?(exitstatus)
      exitstatus == 0
    end
  end

  module HadoopExt
    def hadoop_ext
      @hadoop_ext ||= Hadupils::Extensions::FlatArchivePath.new(Hadupils::Search.hadoop_assets)
    end
  end

  module HiveExt
    def hive_ext
      @hive_ext ||= Hadupils::Extensions::HiveSet.new(Hadupils::Search.hive_extensions)
    end
  end

  module UserConf
    def user_config
      @user_config ||= Hadupils::Extensions::Static.new(Hadupils::Search.user_config)
    end
  end

  class Hadoop < SimpleCommand
    include HadoopExt
    include UserConf

    def assemble_parameters(parameters)
      @hadoop_ext     = Hadupils::Extensions::Static.new(Hadupils::Search.hadoop_assets)
      hadoop_cmd      = parameters[0...1]
      hadoop_cmd_opts = parameters[1..-1] || []

      if %w(fs dfs).include? parameters[0]
        hadoop_cmd + user_config.hadoop_confs + hadoop_ext.hadoop_confs + hadoop_cmd_opts
      else
        # TODO: Assemble command line parameters to pkg assets/code for submitting jobs, for i.e.
        hadoop_cmd + user_config.hadoop_confs + hadoop_ext.hadoop_confs + hadoop_cmd_opts
      end
    end

    def run
      Hadupils::Runners::Hadoop.run assemble_parameters(params)
    end
  end

  register_handler :hadoop, Hadoop

  class Hive < SimpleCommand
    include HadoopExt
    include HiveExt
    include UserConf

    def assemble_parameters(parameters)
      user_config.hivercs + hadoop_ext.hivercs + hive_ext.hivercs + parameters
    end

    def run
      Hadupils::Runners::Hive.run assemble_parameters(params), hive_ext.hive_aux_jars_path
    end
  end

  register_handler :hive, Hive

  class MkTmpFile < SimpleCommand
    include Options::Directory

    attr_reader :tmpdir_path

    def initialize(params)
      super(params)
      Hadupils::Extensions::Dfs::TmpFile.reset_tmpfile!
      @tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path
    end

    def run
      # Similar to shell mktemp, but for Hadoop DFS!
      # Creates a new tmpdir and puts the full tmpdir_path to STDOUT
      # Makes a tmp file by default; a tmp directory with '-d' flag
      fs_cmd = perform_directory? ? '-mkdir' : '-touchz'
      stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', fs_cmd, tmpdir_path]
      if successful? exitstatus
        stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', '-chmod', '700', tmpdir_path]
        if successful? exitstatus
          puts tmpdir_path
        else
          $stderr.puts "Failed to dfs -chmod 700 dfs tmpdir: #{tmpdir_path}"
        end
      else
        $stderr.puts "Failed creating dfs tmpdir: #{tmpdir_path}"
      end
      [nil, exitstatus]
    end
  end

  register_handler :mktemp, MkTmpFile

  class RmFile < SimpleCommand
    include Hadupils::Helpers::TextHelper
    include Options::Recursive

    def assemble_parameters(parameters)
      perform_recursive? ? ['-rmr', parameters[1..-1]] : ['-rm', parameters[0..-1]]
    end

    def run
      # Similar to shell rm, but for Hadoop DFS!
      # Removes files by default; removes directories recursively with '-r' flag
      fs_cmd, tmp_dirs = assemble_parameters(params)

      if tmp_dirs.empty?
        $stderr.puts 'Failed to remove unspecified tmpdir(s), please specify tmpdir_path'
        [nil, 255]
      else
        stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', fs_cmd, tmp_dirs].flatten
        unless successful? exitstatus
          $stderr.puts "Failed to remove #{pluralize(tmp_dirs.length, 'tmpdir', 'tmpdirs')}"
          tmp_dirs.each do |tmp_dir|
            $stderr.puts tmp_dir
          end
        end
        [nil, exitstatus]
      end
    end
  end

  register_handler :rm, RmFile

  class WithTmpDir < SimpleCommand
    def run
      # Runs provided subcommand with tmpdir and cleans up tmpdir on an exitstatus of zero
      if params.empty?
        $stderr.puts 'Yeeaaahhh... sooo... you failed to provide a subcommand...'
        [nil, 255]
      else
        # Let's create the tmpdir
        stdout, exitstatus = Hadupils::Commands::MkTmpFile.run ['-d']
        if successful? exitstatus
          tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path
          params.unshift({'HADUPILS_TMPDIR_PATH' => tmpdir_path})

          # Let's run the shell subcommand!
          stdout, exitstatus = Hadupils::Runners::Subcommand.run params

          if successful? exitstatus
            # Let's attempt to cleanup tmpdir_path
            stdout, exitstatus = Hadupils::Commands::RmFile.run ['-r', tmpdir_path]
          else
            $stderr.puts "Failed to run shell subcommand: #{params}"
          end
        end
        Hadupils::Extensions::Dfs::TmpFile.reset_tmpfile!
        [nil, exitstatus]
      end
    end
  end

  register_handler :withtmpdir, WithTmpDir

  class Cleanup < SimpleCommand
    include Hadupils::Extensions::Dfs
    include Hadupils::Extensions::Runners
    include Hadupils::Helpers::Dfs
    include Hadupils::Helpers::TextHelper
    include Options::DryRun

    attr_accessor :expired_exitstatuses
    attr_accessor :rm_exitstatuses
    attr_reader   :tmp_path
    attr_reader   :tmp_ttl

    def initialize(params)
      super(params)
      @expired_exitstatuses = []
      @rm_exitstatuses      = []
      @tmp_path             = (perform_dry_run? ? params[1] : params[0]) || TmpFile.tmp_path
      @tmp_ttl              = ((perform_dry_run? ? params[2] : params[1]) || TmpFile.tmp_ttl).to_i
    end

    def run
      # Removes old hadupils tmp files/dirs where all files within a tmpdir are also older than the TTL
      # User configurable by setting the ENV variable $HADUPILS_TMP_TTL, defaults to 86400 (last 24 hours)
      # User may also perform a dry-run via a -n or a --dry-run flag

      # Silence the Runner's shell STDOUT noise
      Shell.silence_stdout = true

      # Get candidate directories
      stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', '-ls', tmp_path]
      if successful? exitstatus
        rm_array = []
        dir_candidates(hadupils_tmpfiles(parse_ls(stdout)), tmp_ttl).each do |dir_candidate|
          next unless has_expired? dir_candidate, tmp_ttl
          rm_array << dir_candidate
        end

        exitstatus = expired_exitstatuses.all? {|expired_exitstatus| expired_exitstatus == 0} ? 0 : 255
        if successful? exitstatus
          puts "Found #{pluralize(rm_array.length, 'item', 'items')} to be removed recursively"
          rm_array.each {|rm_item| puts rm_item }

          unless perform_dry_run?
            # Now want the user to see the Runner's shell STDOUT
            Shell.silence_stdout = false

            puts 'Removing...' unless rm_array.empty?
            rm_array.each do |dir|
              rm_stdout, rm_exitstatus = Hadupils::Commands::RmFile.run ['-r', dir]
              rm_exitstatuses << rm_exitstatus
              $stderr.puts "Failed to recursively remove: #{dir}" unless successful? rm_exitstatus
            end
          end
          exitstatus = rm_exitstatuses.all? {|rm_exitstatus| rm_exitstatus == 0} ? 0 : 255
        end
      end
      [nil, exitstatus]
    end

    def has_expired?(dir_candidate, ttl)
      puts "Checking directory candidate: #{dir_candidate}"
      stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', '-count', dir_candidate]
      expired_exitstatuses << exitstatus
      if successful? exitstatus
        parsed_count = parse_count(stdout)
        if parsed_count.empty?
          $stderr.puts "Failed to parse dfs -count for stdout: #{stdout}"
          expired_exitstatuses << 255
        elsif dir_empty? parsed_count[:file_count]
          true
        else
          stdout, exitstatus = Hadupils::Commands::Hadoop.run ['fs', '-ls', File.join(dir_candidate, '**', '*')]
          expired_exitstatuses << exitstatus
          if successful? exitstatus
            all_expired? parse_ls(stdout), ttl
          else
            $stderr.puts "Failed to perform dfs -ls on path: #{File.join(dir_candidate, '**', '*')}"
            false
          end
        end
      else
        $stderr.puts "Failed to perform dfs -count on path: #{dir_candidate}"
        false
      end
    end
  end

  register_handler :cleanup, Cleanup
end
