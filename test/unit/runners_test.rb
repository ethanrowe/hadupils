class Hadupils::RunnersTest < Test::Unit::TestCase
  include Hadupils::Extensions::Runners

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
          $?.stubs(:exitstatus).with.returns(mock())
          last_status = $?
          Shell.stubs(:command).with(*@command).returns([nil, nil, last_status])
          @runner.wait!
        end

        should 'return 255 when system returns nil' do
          Shell.stubs(:command).returns([nil, nil, nil])
          assert_equal [nil, 255], @runner.wait!
        end

        should 'return Process::Status#exitstatus when non-nil system result' do
          $?.stubs(:exitstatus).with.returns(status = mock())
          last_status = $?
          Shell.stubs(:command).returns([nil, nil, last_status])
          assert_equal [nil, status], @runner.wait!
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
          Open3.expects(:popen3).with(*@command)
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
            last_status = $?
            matcher = Shell.stubs(:command).returns([nil, nil, last_status]).with do |*args|
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
end
