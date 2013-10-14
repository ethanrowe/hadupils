class Hadupils::RunnersTest < Test::Unit::TestCase
  context Hadupils::Runners::Base do
    setup do
      @runner = Hadupils::Runners::Base.new(@params = mock())
    end

    should 'expose initialization params as attr' do
      assert_equal @params, @runner.params
    end

    context 'wait!' do
      setup do
        @command = [mock(), mock(), mock()]
        # This will ensure that $? is non-nil
        system(RbConfig.ruby, '-v')
      end

      context 'with semi-modern ruby' do
        setup do
          @runner.expects(:command).with.returns(@command)
        end

        should 'assemble system call via command method' do
          Kernel.expects(:system).with(*@command).returns(true)
          $?.stubs(:exitstatus).with.returns(mock())
          @runner.wait!
        end

        should 'return 255 when system returns nil' do
          Kernel.stubs(:system).returns(nil)
          assert_equal 255, @runner.wait!
        end

        should 'return Process::Status#exitstatus when non-nil system result' do
          Kernel.stubs(:system).returns(true)
          $?.stubs(:exitstatus).with.returns(status = mock())
          assert_equal status, @runner.wait!
        end
      end

      context 'with ruby pre 1.9' do
        setup do
          @orig_ruby_version = ::RUBY_VERSION
          ::RUBY_VERSION = '1.8.7'
        end

        teardown do
          ::RUBY_VERSION = @orig_ruby_version
        end

        should 'handle command without env hash normally' do
          @runner.expects(:command).with.returns(@command)
          Kernel.expects(:system).with(*@command).returns(true)
          $?.stubs(:exitstatus).with.returns(mock)
          @runner.wait!
        end

        should 'handle environment hash specially and restore env' do
          # A defined environment variable to play with.
          var = ::ENV.keys.find {|k| ENV[k].strip.length > 0}
          orig = ::ENV[var]
          to_be_removed = ::ENV.keys.sort[-1] + 'X'
          removal_val = mock.to_s
          replacement = "#{orig}-#{mock.to_s}"
          @runner.expects(:command).with.returns([{var => replacement, to_be_removed => removal_val}] + @command)
          $?.stubs(:exitstatus).with.returns(mock)
          begin
            # Environment variable is overridden during system call
            matcher = Kernel.expects(:system).with do |*args|
              args == @command and ::ENV[var] == replacement and ::ENV[to_be_removed] == removal_val
            end

            matcher.returns true

            @runner.wait!

            # But is restored afterward
            assert_equal orig, ::ENV[var]
            assert_equal false, ::ENV.has_key?(to_be_removed)
          ensure
            ::ENV[var] = orig
          end
        end
      end
    end
  end

  context Hadupils::Runners::Hadoop do
    setup do
      @klass = Hadupils::Runners::Hadoop
    end

    should 'be a runner' do
      assert_kind_of Hadupils::Runners::Base, @klass.new([])
    end

    should 'use $HADOOP_HOME/bin/hadoop as the base runner' do
      ENV.expects(:[]).with('HADOOP_HOME').returns(home = mock().to_s)
      assert_equal ::File.join(home, 'bin', 'hadoop'),
                   @klass.base_runner
    end

    context '#command' do
      setup do
        @klass.stubs(:base_runner).returns(@hadoop_path = mock().to_s + '-hadoop')
      end

      should 'provide invocation for bare hadoop if given empty parameters' do
        assert_equal [@hadoop_path], @klass.new([]).command
      end

      should 'provide invocation for hadoop with all given parameters' do
        params = [mock().to_s, mock().to_s, mock().to_s, mock().to_s]
        assert_equal [@hadoop_path] + params,
                     @klass.new(params).command
      end

      should 'provide args for hadoop with :hadoop_opts on supporting params' do
        p1 = mock()
        p1.expects(:hadoop_opts).with.returns(p1_opts = ['-conf', mock().to_s])
        p2 = mock()
        p2.expects(:hadoop_opts).with.returns(p2_opts = ['-conf', mock().to_s])
        s1 = mock().to_s
        s2 = mock().to_s
        assert_equal [@hadoop_path, s1] + p1_opts + p2_opts + [s2],
                     @klass.new([s1, p1, p2, s2]).command
      end
    end
  end

  context Hadupils::Runners::MkTmpFile do
    setup do
      @klass = Hadupils::Runners::MkTmpFile
    end

    should 'be a runner' do
      assert_kind_of Hadupils::Runners::Base, @klass.new([])
    end

    context '#command' do
      setup do
        Hadupils::Runners::Hadoop.stubs(:base_runner).returns(@hadoop_path = mock().to_s + '-hadoop')
      end

      should 'provide invocation for bare mktemp if given empty parameters' do
        tmpdir_path = mock().to_s
        Hadupils::Extensions::Dfs::TmpFile.expects(:tmpfile_path).returns(tmpdir_path)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-touchz', tmpdir_path).returns(0)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-chmod', '700', tmpdir_path).returns(0)
        assert_equal 0, @klass.new([]).command
      end

      should 'provide invocation for mktemp if given with -d flag parameter' do
        tmpdir_path = mock().to_s
        Hadupils::Extensions::Dfs::TmpFile.expects(:tmpfile_path).returns(tmpdir_path)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-mkdir', tmpdir_path).returns(0)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-chmod', '700', tmpdir_path).returns(0)
        assert_equal 0, @klass.new(['-d']).command
      end
    end
  end

  context Hadupils::Runners::WithTmpDir do
    setup do
      @klass = Hadupils::Runners::WithTmpDir
    end

    should 'be a runner' do
      assert_kind_of Hadupils::Runners::Base, @klass.new([])
    end

    context '#command' do
      setup do
        Hadupils::Runners::Hadoop.stubs(:base_runner).returns(@hadoop_path = mock().to_s + '-hadoop')
      end

      should 'provide invocation for bare withtmpdir if given empty parameters' do
        assert_equal 255, @klass.new([]).command
      end

      should 'provide invocation for withtmpdir if given parameters for shell subcommand' do
        tmpdir_path = mock().to_s
        run_common_subcommand_assertions_with tmpdir_path
        Kernel.expects(:system).with({'HADUPILS_TMPDIR_PATH' => tmpdir_path}, '/path/to/my_wonderful_script.sh').returns(0)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-rmr', tmpdir_path).returns(0)
        assert_equal 0, @klass.new(['/path/to/my_wonderful_script.sh']).command
      end

      should 'provide invocation for withtmpdir if given parameters for shell subcommand (another hadupils command)' do
        tmpdir_path = mock().to_s
        run_common_subcommand_assertions_with tmpdir_path
        Kernel.expects(:system).with({'HADUPILS_TMPDIR_PATH' => tmpdir_path}, 'hadupils hadoop ls /tmp').returns(0)
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-rmr', tmpdir_path).returns('')
        assert_equal 0, @klass.new(['hadupils hadoop ls /tmp']).command
      end

      should 'provide invocation for withtmpdir if given parameters for shell subcommand with nil result' do
        tmpdir_path = mock().to_s
        run_common_subcommand_assertions_with tmpdir_path
        Kernel.expects(:system).with({'HADUPILS_TMPDIR_PATH' => tmpdir_path}, '/path/to/my_wonderful_script.sh').returns(nil)
        assert_equal 255, @klass.new(['/path/to/my_wonderful_script.sh']).command
      end
    end
  end

  context Hadupils::Runners::RmFile do
    setup do
      @klass = Hadupils::Runners::RmFile
    end

    should 'be a runner' do
      assert_kind_of Hadupils::Runners::Base, @klass.new([])
    end

    context '#command' do
      setup do
        Hadupils::Runners::Hadoop.stubs(:base_runner).returns(@hadoop_path = mock().to_s + '-hadoop')
      end

      should 'provide invocation for bare rm if given empty parameters' do
        assert_equal 255, @klass.new([]).command
      end

      should 'provide invocation for rm if just tmpdir_path parameter' do
        tmpdir_path = mock().to_s
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-rm', tmpdir_path).returns(0)
        assert_equal 0, @klass.new([tmpdir_path]).command
      end

      should 'provide invocation for hadoop if just tmpdir_path with -r flag parameter' do
        tmpdir_path = mock().to_s
        Kernel.expects(:system).with(@hadoop_path, 'fs', '-rmr', tmpdir_path).returns(0)
        assert_equal 0, @klass.new(['-r', tmpdir_path]).command
      end
    end
  end

  context Hadupils::Runners::Hive do
    setup do
      @klass = Hadupils::Runners::Hive
    end

    should 'be a runner' do
      assert_kind_of Hadupils::Runners::Base, @klass.new([])
    end

    should 'use $HIVE_HOME/bin/hive as the base runner' do
      ENV.expects(:[]).with('HIVE_HOME').returns(home = mock().to_s)
      assert_equal ::File.join(home, 'bin', 'hive'),
                   @klass.base_runner
    end

    context '#command' do
      setup do
        @klass.stubs(:base_runner).returns(@hive_path = mock().to_s + '-hive')
      end

      should 'provide invocation for bare hive if given empty parameters' do
        assert_equal [{}, @hive_path], @klass.new([]).command
      end

      should 'provide invocation with aux jars and bare hive given empty params but aux jars path' do
        ENV.stubs(:[]=).with('HIVE_AUX_JARS_PATH').returns(nil)
        assert_equal [{'HIVE_AUX_JARS_PATH' => 'foo'}, @hive_path],
                     @klass.new([], 'foo').command
      end

      should 'provide invocation with merged aux jars given otherwise bare stuff' do
        ::ENV.stubs(:[]).with('HIVE_AUX_JARS_PATH').returns(orig = mock.to_s)
        additional = mock.to_s
        assert_equal [{'HIVE_AUX_JARS_PATH' => "#{additional},#{orig}"}, @hive_path],
                     @klass.new([], additional).command
      end

      should 'provide invocation for hive with all given parameters' do
        params = [mock().to_s, mock().to_s, mock().to_s, mock().to_s]
        assert_equal [{}, @hive_path] + params,
                     @klass.new(params).command
      end

      should 'provide args for hive with :hive_opts on supporting params' do
        p1 = mock()
        p1.expects(:hive_opts).with.returns(p1_opts = ['-i', mock().to_s])
        p2 = mock()
        p2.expects(:hive_opts).with.returns(p2_opts = ['-i', mock().to_s])
        s1 = mock().to_s
        s2 = mock().to_s
        assert_equal [{}, @hive_path, s1] + p1_opts + [s2] + p2_opts,
                     @klass.new([s1, p1, s2, p2]).command
      end
    end
  end

  def run_common_subcommand_assertions_with(tmpdir_path)
    Hadupils::Extensions::Dfs::TmpFile.expects(:tmpfile_path).returns(tmpdir_path)
    Hadupils::Extensions::Dfs::TmpFile.expects(:tmpfile_path).returns(tmpdir_path)
    Kernel.expects(:system).with(@hadoop_path, 'fs', '-mkdir', tmpdir_path).returns(0)
    Kernel.expects(:system).with(@hadoop_path, 'fs', '-chmod', '700', tmpdir_path).returns(0)
  end
end
