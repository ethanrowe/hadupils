module Hadupils::Runners
  class Base
    attr_reader :params, :last_result, :last_status

    def initialize(params)
      @params = params
    end

    def self.run(*params)
      self.new(*params).wait!
    end

    def command; end

    def execute!
      command_list = command
      if RUBY_VERSION < '1.9' and command_list[0].kind_of? Hash
        deletes = []
        overrides = {}
        begin
          command_list[0].each do |key, val|
            if ::ENV.has_key? key
              overrides[key] = ::ENV[key]
            else
              deletes << key
            end
            ::ENV[key] = val
          end
          Kernel.system(*command_list[1..-1])
        ensure
          overrides.each {|key, val| ::ENV[key] = val }
          deletes.each {|key| ::ENV.delete key }
        end
      else
        Kernel.system(*command_list)
      end
    end

    def wait!
      @last_result = execute!
      @last_status = $?
      last_exitstatus
    end

    def successful?(exitstatus)
      exitstatus == 0
    end

    def last_exitstatus
      if @last_result.nil?
        255
      else
        @last_status.exitstatus
      end
    end
  end

  class Hive < Base
    class << self; attr_writer :base_runner; end

    def initialize(params, hive_aux_jars_path='')
      super(params)
      @hive_aux_jars_path = hive_aux_jars_path
    end

    def self.base_runner
      @base_runner || ::File.join(ENV['HIVE_HOME'], 'bin', 'hive')
    end

    def command
      params.inject([env_overrides, self.class.base_runner]) do |result, param|
        if param.respond_to? :hive_opts
          result + param.hive_opts
        else
          result << param
        end
      end
    end

    def env_overrides
      env = {}
      settings = [@hive_aux_jars_path, ::ENV['HIVE_AUX_JARS_PATH']].reject do |val|
        val.nil? || val.strip.empty?
      end
      if settings.length > 0
        env['HIVE_AUX_JARS_PATH'] = settings.join(',')
      end
      env
    end
  end

  class Hadoop < Base
    class << self; attr_writer :base_runner; end

    def self.base_runner
      @base_runner || ::File.join(ENV['HADOOP_HOME'], 'bin', 'hadoop')
    end

    def command
      params.inject([self.class.base_runner]) do |result, param|
        if param.respond_to? :hadoop_opts
          result + param.hadoop_opts
        else
          result << param
        end
      end
    end
  end

  class MkTmpFile < Base
    def command
      # Creates a new tmpdir and puts the full tmpdir_path to STDOUT
      Hadupils::Extensions::Dfs::TmpFile.reset_tmpfile!
      tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path

      # Similar to shell mktemp, but for Hadoop DFS!
      # Makes a tmp file by default; a tmp directory with '-d' flag
      fs_cmd = params[0] == '-d' ? '-mkdir' : '-touchz'
      exitstatus = Hadupils::Commands::Hadoop.run ['fs', fs_cmd, tmpdir_path]
      if successful? exitstatus
        exitstatus = Hadupils::Commands::Hadoop.run ['fs', '-chmod', '700', tmpdir_path]
        if successful? exitstatus
          puts tmpdir_path
        else
          $stderr.puts "Failed to chmod 700 dfs tmpdir: #{tmpdir_path}"
        end
      else
        $stderr.puts "Failed creating dfs tmpdir: #{tmpdir_path}"
      end
      exitstatus
    end

    def execute!
      command
    end

    def wait!
      execute!
    end
  end

  class WithTmpDir < Base
    # Runs provided subcommand with tmpdir and cleans up tmpdir on an exitstatus of zero
    def command
      if params.empty?
        $stderr.puts 'Yeeaaahhh... sooo... you failed to provide a subcommand...'
        255
      else
        # Let's create the tmpdir
        exitstatus = Hadupils::Commands::MkTmpFile.run ['-d']
        if successful? exitstatus
          tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path

          # Let's run the shell subcommand!
          exitstatus = Hadupils::Runners::Subcommand.run params.unshift({'HADUPILS_TMPDIR_PATH' => tmpdir_path})

          if successful? exitstatus
            # Let's attempt to cleanup tmpdir_path
            exitstatus = Hadupils::Commands::RmFile.run ['-r', tmpdir_path]
          else
            $stderr.puts "Failed to run shell subcommand: #{params}"
          end
        end
        exitstatus
      end
    end

    def execute!
      command
    end

    def wait!
      execute!
    end
  end

  class RmFile < Base
    def command
      # Similar to shell rm, but for Hadoop DFS!
      # Removes files by default; removes directories recursively with '-r' flag
      fs_cmd, tmp_dirs =
        if params[0] == '-r'
          ['-rmr', params[1..-1]]
        else
          ['-rm', params[0..-1]]
        end

      if tmp_dirs.empty?
        $stderr.puts 'Failed to remove unspecified tmpdir(s), please specify tmpdir_path'
        255
      else
        exitstatus = Hadupils::Commands::Hadoop.run ['fs', fs_cmd, tmp_dirs].flatten
        if successful? exitstatus
          Hadupils::Extensions::Dfs::TmpFile.reset_tmpfile!
        else
          $stderr.puts "Failed to remove dfs tmpdir: #{tmp_dirs.join(' ')}"
        end
        exitstatus
      end
    end

    def execute!
      command
    end

    def wait!
      execute!
    end
  end

  class Subcommand < Base
    def command
      params
    end
  end
end
