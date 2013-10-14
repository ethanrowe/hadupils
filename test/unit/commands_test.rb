using Hadupils::Hacks unless RUBY_VERSION < '2.0'

class Hadupils::CommandsTest < Test::Unit::TestCase
  context Hadupils::Commands do
    context 'run singleton method' do
      should 'pass trailing params to #run method of handler identified by first param' do
        Hadupils::Commands.expects(:handler_for).with(cmd = mock()).returns(handler = mock())
        handler.expects(:run).with(params = [mock(), mock(), mock()]).returns(result = mock())
        assert_equal result, Hadupils::Commands.run(cmd, params)
      end
    end

    # Addresses bug when run on older rubies
    context 'handler pretty name normalization' do
      context 'via handler_for' do
        should 'not invoke downcase on requested handler' do
          pretty = mock()
          pretty.expects(:downcase).never
          Hadupils::Commands.handler_for(pretty)
        end

        should 'produce downcased string' do
          pretty = mock()
          pretty.expects(:to_s).returns(s = mock())
          s.expects(:downcase)
          Hadupils::Commands.handler_for(pretty)
        end
      end
    end

    context 'Hadoop' do
      setup do
        @klass = Hadupils::Commands::Hadoop
      end

      should 'register with :hadoop name' do
        handlers = [:hadoop]
        run_handler_assertions_for handlers
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      should 'have a Static extension based on a search for hadoop-ext' do
        Hadupils::Search.expects(:hadoop_assets).with.returns(conf = mock())
        Hadupils::Extensions::Static.expects(:new).with(conf).returns(extension = mock())
        hadoop_ext = Hadupils::Extensions::Static.new(Hadupils::Search.hadoop_assets)
        cmd = @klass.new
        cmd.stubs(:hadoop_ext).with.returns(hadoop_ext)
        assert_equal extension, cmd.hadoop_ext
        # This should cause failure if the previous result wasn't
        # cached internally (by breaking expectations).
        cmd.hadoop_ext
      end

      should 'have a Static extensions based on user config' do
        Hadupils::Search.expects(:user_config).with.returns(conf = mock())
        Hadupils::Extensions::Static.expects(:new).with(conf).returns(extension = mock())
        cmd = @klass.new
        assert_equal extension, cmd.user_config
        # Fails on expectations if previous result wasn't cached.
        cmd.user_config
      end

      context '#run' do
        setup do
          @command = @klass.new
          @command.stubs(:user_config).with.returns(@user_config = mock())
          @command.stubs(:hadoop_ext).with.returns(@hadoop_ext = mock())
          @runner_class = Hadupils::Runners::Hadoop
        end

        context 'with user config and hadoop_confs' do
          setup do
            @user_config.stubs(:hadoop_confs).returns(@user_config_hadoop_confs = [mock(), mock()])
            @hadoop_ext.stubs(:hadoop_confs).returns(@hadoop_ext_hadoop_confs = [mock(), mock(), mock()])
          end

          should 'apply hadoop_conf options to hadoop runner call' do
            @runner_class.expects(:run).with(@user_config_hadoop_confs +
                                             @hadoop_ext_hadoop_confs).returns(result = mock())
            assert_equal result, @command.run([])
          end

          should 'insert hadoop_conf options into position 1 of given params array to hadoop runner call' do
            params = [mock(), mock()]
            @runner_class.expects(:run).with(params[0...1] +
                                             @user_config_hadoop_confs +
                                             @hadoop_ext_hadoop_confs +
                                             params[1..-1]).returns(result = mock())
            assert_equal result, @command.run(params)
          end
        end

        context 'without hadoop_confs' do
          setup do
            @user_config.stubs(:hadoop_confs).returns([])
            @hadoop_ext.stubs(:hadoop_confs).returns([])
          end

          should 'pass params unchanged through to hadoop runner call' do
            @runner_class.expects(:run).with(params = [mock(), mock()]).returns(result = mock())
            assert_equal result, @command.run(params)
          end

          should 'handle empty params' do
            @runner_class.expects(:run).with([]).returns(result = mock())
            assert_equal result, @command.run([])
          end
        end
      end
    end

    context 'MkTempFile' do
      setup do
        @klass = Hadupils::Commands::MkTmpFile
      end

      should 'register with :mktemp name' do
        handlers = [:mktemp]
        run_handler_assertions_for handlers
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      context '#run' do
        setup do
          @command = @klass.new
          @runner_class = Hadupils::Runners::MkTmpFile
        end

        should 'with command mktemp' do
          params = [mock(), mock(), mock()]
          Hadupils::Runners::MkTmpFile.expects(:run).with(params).returns(result = mock())
          assert_equal result, @command.run(params)
        end
      end
    end

    context 'WithTempDir' do
      setup do
        @klass = Hadupils::Commands::WithTmpDir
      end

      should 'register with :withtmpdir name' do
        handlers = [:withtmpdir]
        run_handler_assertions_for handlers
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      context '#run' do
        setup do
          @command = @klass.new
          @runner_class = Hadupils::Runners::WithTmpDir
        end

        should 'with command withtmpdir' do
          params = [mock(), mock(), mock()]
          Hadupils::Runners::WithTmpDir.expects(:run).with(params).returns(result = mock())
          assert_equal result, @command.run(params)
        end
      end
    end

    context 'RmFile' do
      setup do
        @klass = Hadupils::Commands::RmFile
      end

      should 'register with :rm name' do
        handlers = [:rm]
        run_handler_assertions_for handlers
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      context '#run' do
        setup do
          @command = @klass.new
          @runner_class = Hadupils::Runners::RmFile
        end

        should 'with command rm' do
          params = [mock(), mock(), mock()]
          Hadupils::Runners::RmFile.expects(:run).with(params).returns(result = mock())
          assert_equal result, @command.run(params)
        end
      end
    end

    context 'Hive' do
      setup do
        @klass = Hadupils::Commands::Hive
      end

      should 'register with :hive name' do
        handlers = [:hive]
        run_handler_assertions_for handlers
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      should 'have a FlatArchivePath extension based on a search for hadoop-ext' do
        Hadupils::Search.expects(:hadoop_assets).with.returns(assets = mock())
        Hadupils::Extensions::FlatArchivePath.expects(:new).with(assets).returns(extension = mock())
        cmd = @klass.new
        assert_equal extension, cmd.hadoop_ext
        # This should cause failure if the previous result wasn't
        # cached internally (by breaking expectations).
        cmd.hadoop_ext
      end

      should 'have a Static extensions based on user config' do
        Hadupils::Search.expects(:user_config).with.returns(conf = mock())
        Hadupils::Extensions::Static.expects(:new).with(conf).returns(extension = mock())
        cmd = @klass.new
        assert_equal extension, cmd.user_config
        # Fails on expectations if previous result wasn't cached.
        cmd.user_config
      end

      should 'have a HiveSet extension based on search for hive-ext' do
        Hadupils::Search.expects(:hive_extensions).with.returns(path = mock())
        Hadupils::Extensions::HiveSet.expects(:new).with(path).returns(extension = mock)
        cmd = @klass.new
        assert_equal extension, cmd.hive_ext
        # Fails on expectations if previous result wasn't cached.
        cmd.hive_ext
      end

      context '#run' do
        setup do
          @command = @klass.new
          @command.stubs(:user_config).with.returns(@user_config = mock())
          @command.stubs(:hadoop_ext).with.returns(@hadoop_ext = mock())
          @command.stubs(:hive_ext).with.returns(@hive_ext = mock)
          @runner_class = Hadupils::Runners::Hive
        end

        context 'with user config, hadoop assets, hive ext hivercs and aux jars' do
          setup do
            @user_config.stubs(:hivercs).returns(@user_config_hivercs = [mock(), mock()])
            @hadoop_ext.stubs(:hivercs).returns(@hadoop_ext_hivercs = [mock(), mock(), mock()])
            @hive_ext.stubs(:hivercs).returns(@hive_ext_hivercs = [mock, mock, mock])
            @hive_ext.stubs(:hive_aux_jars_path).returns(@hive_aux_jars_path = mock.to_s)
          end

          should 'apply hiverc options to hive runner call' do
            @runner_class.expects(:run).with(@user_config_hivercs +
                                             @hadoop_ext_hivercs +
                                             @hive_ext_hivercs,
                                             @hive_aux_jars_path).returns(result = mock())
            assert_equal result, @command.run([])
          end

          should 'prepend hiverc options before given params to hive runner call' do
            params = [mock(), mock()]
            @runner_class.expects(:run).with(@user_config_hivercs +
                                             @hadoop_ext_hivercs +
                                             @hive_ext_hivercs +
                                             params,
                                             @hive_aux_jars_path).returns(result = mock())
            assert_equal result, @command.run(params)
          end
        end

        context 'without hivercs' do
          setup do
            @user_config.stubs(:hivercs).returns([])
            @hadoop_ext.stubs(:hivercs).returns([])
            @hive_ext.stubs(:hivercs).returns([])
            @hive_ext.stubs(:hive_aux_jars_path).returns('')
          end

          should 'pass params unchanged through to hive runner call along with aux jars path' do
            @runner_class.expects(:run).with(params = [mock(), mock()], '').returns(result = mock())
            assert_equal result, @command.run(params)
          end

          should 'handle empty params' do
            @runner_class.expects(:run).with([], '').returns(result = mock())
            assert_equal result, @command.run([])
          end
        end
      end

      tempdir_context 'running for (mostly) realz' do
        setup do
          @conf = ::File.join(@tempdir.path, 'conf')
          @ext  = ::File.join(@tempdir.path, 'hadoop-ext')
          @hive_ext = @tempdir.full_path('hive-ext')

          ::Dir.mkdir(@conf)
          ::Dir.mkdir(@ext)
          ::Dir.mkdir(@hive_ext)
          @hiverc = @tempdir.file(File.join('conf', 'hiverc')) do |f|
            f.write(@static_hiverc_content = 'my static content;')
            f.path
          end
          file = Proc.new {|base, name| @tempdir.file(::File.join(base, name)).path }
          @ext_file  = file.call('hadoop-ext', 'a_file.yaml')
          @ext_jar   = file.call('hadoop-ext', 'a_jar.jar')
          @ext_tar   = file.call('hadoop-ext', 'a_tar.tar.gz')
          @dynamic_hiverc_content = ["ADD FILE #{@ext_file}",
                                     "ADD JAR #{@ext_jar}",
                                     "ADD ARCHIVE #{@ext_tar}"].join(";\n") + ";\n"

          # Assemble two entries under hive-ext
          @hive_exts = %w(one two).inject({}) do |result, name|
            state = result[name.to_sym] = {}
            state[:path] = ::File.join(@hive_ext, name)

            ::Dir.mkdir(state[:path])
            state[:static_hiverc] = ::File.open(::File.join(state[:path], 'hiverc'), 'w') do |file|
              file.write(state[:static_hiverc_content] = "#{name} static content")
              file.path
            end

            assets = state[:assets] = %w(a.tar.gz b.txt c.jar).collect do |base|
              ::File.open(::File.join(state[:path], "#{name}-#{base}"), 'w') do |file|
                file.path
              end
            end

            state[:dynamic_hiverc_content] = ["ADD ARCHIVE #{assets[0]};",
                                              "ADD FILE #{assets[1]};",
                                              "ADD JAR #{assets[2]};"].join("\n") + "\n"

            aux_path = state[:aux_path] = ::File.join(state[:path], 'aux-jars')
            ::Dir.mkdir(aux_path)
            state[:aux_jars] = %w(boo foo).collect do |base|
              ::File.open(::File.join(aux_path, "#{name}-#{base}.jar"), 'w') do |file|
                file.path
              end
            end

            state[:hive_aux_jars_path] = state[:aux_jars].join(',')

            result
          end

          # Can't use a simple stub for this because other things are
          # checked within ENV.  Use a teardown to reset to its original state.
          @orig_hive_aux_jars_path = ENV['HIVE_AUX_JARS_PATH']
          ::ENV['HIVE_AUX_JARS_PATH'] = env_aux = mock.to_s
          @hive_aux_jars_path_val = [@hive_exts[:one][:hive_aux_jars_path],
                                     @hive_exts[:two][:hive_aux_jars_path],
                                     env_aux].join(',')

          @pwd       = ::Dir.pwd
          Hadupils::Search.stubs(:user_config).with.returns(@conf)
          Hadupils::Runners::Hive.stubs(:base_runner).with.returns(@hive_prog = '/opt/hive/bin/hive')
          ::Dir.chdir @tempdir.path
        end

        teardown do
          if @orig_hive_aux_jars_path
            ENV['HIVE_AUX_JARS_PATH'] = @orig_hive_aux_jars_path
          else
            ENV.delete 'HIVE_AUX_JARS_PATH'
          end
        end

        should 'produce a valid set of parameters and hivercs' do
          Kernel.stubs(:system).with() do |*args|
            args[0] == {'HIVE_AUX_JARS_PATH' => @hive_aux_jars_path_val} &&
            args[1] == @hive_prog &&
            args[2] == '-i' &&
            File.open(args[3], 'r').read == @static_hiverc_content &&
            args[4] == '-i' &&
            File.open(args[5], 'r').read == @dynamic_hiverc_content &&
            args[6] == '-i' &&
            File.open(args[7], 'r').read == @hive_exts[:one][:dynamic_hiverc_content] &&
            args[8] == '-i' &&
            File.open(args[9], 'r').read == @hive_exts[:one][:static_hiverc_content] &&
            args[10] == '-i' &&
            File.open(args[11], 'r').read == @hive_exts[:two][:dynamic_hiverc_content] &&
            args[12] == '-i' &&
            File.open(args[13], 'r').read == @hive_exts[:two][:static_hiverc_content] &&
            args[14] == '--hiveconf' &&
            args[15] == 'my.foo=your.fu'
          end
          Hadupils::Commands.run 'hive', ['--hiveconf', 'my.foo=your.fu']
        end

        teardown do
          ::Dir.chdir @pwd
        end
      end
    end
  end

  def run_handler_assertions_for(handlers)
    handlers.each do |handler|
      handler = handler.to_s.downcase
      assert_same @klass, Hadupils::Commands.handler_for(handler.to_sym)
      assert_same @klass, Hadupils::Commands.handler_for(handler.randcase.to_sym)
      assert_same @klass, Hadupils::Commands.handler_for(handler)
      assert_same @klass, Hadupils::Commands.handler_for(handler.randcase)
    end
  end
end
