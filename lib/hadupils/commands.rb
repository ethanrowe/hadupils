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
    def self.run(params=[])
      self.new.run params
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
      @hadoop_ext = Hadupils::Extensions::Static.new(Hadupils::Search.hadoop_assets)
      hadoop_cmd      = parameters[0...1]
      hadoop_cmd_opts  = parameters[1..-1] || []

      if %w(fs dfs).include? parameters[0]
        hadoop_cmd + user_config.hadoop_confs + hadoop_ext.hadoop_confs + hadoop_cmd_opts
      else
        # TODO: Assemble command line parameters to pkg assets/code for submitting jobs, for i.e.
        hadoop_cmd + user_config.hadoop_confs + hadoop_ext.hadoop_confs + hadoop_cmd_opts
      end
    end

    def run(parameters)
      Hadupils::Runners::Hadoop.run assemble_parameters(parameters)
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

    def run(parameters)
      Hadupils::Runners::Hive.run assemble_parameters(parameters), hive_ext.hive_aux_jars_path
    end
  end

  register_handler :hive, Hive

  class MkTmpFile < SimpleCommand
    def run(parameters)
      # Creates a new tmpdir and puts the full tmpdir_path to STDOUT
      Hadupils::Extensions::Dfs::TmpFile.reset_tmpfile!
      tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path

      # Similar to shell mktemp, but for Hadoop DFS!
      # Makes a tmp file by default; a tmp directory with '-d' flag
      fs_cmd = parameters[0] == '-d' ? '-mkdir' : '-touchz'
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
  end

  register_handler :mktemp, MkTmpFile

  class RmFile < SimpleCommand
    def run(parameters)
      # Similar to shell rm, but for Hadoop DFS!
      # Removes files by default; removes directories recursively with '-r' flag
      fs_cmd, tmp_dirs =
        if parameters[0] == '-r'
          ['-rmr', parameters[1..-1]]
        else
          ['-rm', parameters[0..-1]]
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
  end

  register_handler :rm, RmFile

  class WithTmpDir < SimpleCommand
    def run(parameters)
      # Runs provided subcommand with tmpdir and cleans up tmpdir on an exitstatus of zero
      if parameters.empty?
        $stderr.puts 'Yeeaaahhh... sooo... you failed to provide a subcommand...'
        255
      else
        # Let's create the tmpdir
        exitstatus = Hadupils::Commands::MkTmpFile.run ['-d']
        if successful? exitstatus
          tmpdir_path = Hadupils::Extensions::Dfs::TmpFile.tmpfile_path
          parameters.unshift({'HADUPILS_TMPDIR_PATH' => tmpdir_path})

          # Let's run the shell subcommand!
          exitstatus = Hadupils::Runners::Subcommand.run parameters

          if successful? exitstatus
            # Let's attempt to cleanup tmpdir_path
            exitstatus = Hadupils::Commands::RmFile.run ['-r', tmpdir_path]
          else
            $stderr.puts "Failed to run shell subcommand: #{parameters}"
          end
        end
        exitstatus
      end
    end
  end

  register_handler :withtmpdir, WithTmpDir
end
