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

    context 'Hive' do
      setup do
        @klass = Hadupils::Commands::Hive
      end

      should 'register with :hive name' do
        assert_same @klass, Hadupils::Commands.handler_for(:hive)
        assert_same @klass, Hadupils::Commands.handler_for(:HivE)
        assert_same @klass, Hadupils::Commands.handler_for('hive')
        assert_same @klass, Hadupils::Commands.handler_for('hIVe')
      end

      should 'have a #run singleton method that dispatches to an instance #run' do
        @klass.expects(:new).with.returns(instance = mock())
        instance.expects(:run).with(params = mock()).returns(result = mock())
        assert_equal result, @klass.run(params)
      end

      should 'have a Flat extension based on a search for hadoop-ext' do
        Hadupils::Search.expects(:hadoop_assets).with.returns(assets = mock())
        Hadupils::Extensions::Flat.expects(:new).with(assets).returns(extension = mock())
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

      context '#run' do
        setup do
          @command = @klass.new
          @command.stubs(:user_config).with.returns(@user_config = mock())
          @command.stubs(:hadoop_ext).with.returns(@hadoop_ext = mock())
          @runner_class = Hadupils::Runners::Hive
        end

        context 'with user config and hadoop asssets hivercs' do
          setup do
            @user_config.stubs(:hivercs).returns(@user_config_hivercs = [mock(), mock()])
            @hadoop_ext.stubs(:hivercs).returns(@hadoop_ext_hivercs = [mock(), mock(), mock()])
          end

          should 'apply hiverc options to hive runner call' do
            @runner_class.expects(:run).with(@user_config_hivercs + @hadoop_ext_hivercs).returns(result = mock())
            assert_equal result, @command.run([])
          end

          should 'prepend hiverc options before given params to hive runner call' do
            params = [mock(), mock()]
            @runner_class.expects(:run).with(@user_config_hivercs + @hadoop_ext_hivercs + params).returns(result = mock())
            assert_equal result, @command.run(params)
          end
        end

        context 'without hivercs' do
          setup do
            @user_config.stubs(:hivercs).returns([])
            @hadoop_ext.stubs(:hivercs).returns([])
          end

          should 'pass params unchanged through to hive runner call' do
            @runner_class.expects(:run).with(params = [mock(), mock()]).returns(result = mock())
            assert_equal result, @command.run(params)
          end

          should 'handle empty params' do
            @runner_class.expects(:run).with([]).returns(result = mock())
            assert_equal result, @command.run([])
          end
        end
      end

      tempdir_context 'running for (mostly) realz' do
        setup do
          @conf = ::File.join(@tempdir.path, 'conf')
          @ext  = ::File.join(@tempdir.path, 'hadoop-ext')
          ::Dir.mkdir(@conf)
          ::Dir.mkdir(@ext)
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
          @pwd       = ::Dir.pwd
          Hadupils::Search.stubs(:user_config).with.returns(@conf)
          Hadupils::Runners::Hive.stubs(:base_runner).with.returns(@hive_prog = '/opt/hive/bin/hive')
          ::Dir.chdir @tempdir.path
        end

        should 'produce a valid set of parameters and hivercs' do
          Kernel.stubs(:system).with() do |*args|
            args[0] == @hive_prog and
            args[1] == '-i' and
            File.open(args[2], 'r').read == @static_hiverc_content and
            args[3] == '-i' and
            File.open(args[4], 'r').read == @dynamic_hiverc_content and
            args[5] == '--hiveconf' and
            args[6] == 'my.foo=your.fu'
          end
          Hadupils::Commands.run 'hive', ['--hiveconf', 'my.foo=your.fu']
        end

        teardown do
          ::Dir.chdir @pwd
        end
      end
    end
  end
end

