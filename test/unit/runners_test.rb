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
        @runner.expects(:command).with.returns(@command)
        # This will ensure that $? is non-nil
        system(RbConfig.ruby, '-v')
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
        assert_equal [@hive_path], @klass.new([]).command
      end

      should 'provide invocation for hive with all given parameters' do
        params = [mock().to_s, mock().to_s, mock().to_s, mock().to_s]
        assert_equal [@hive_path] + params,
                     @klass.new(params).command
      end

      should 'provide args for hive with :hive_opts on supporting params' do
        p1 = mock()
        p1.expects(:hive_opts).with.returns(p1_opts = ['-i', mock().to_s])
        p2 = mock()
        p2.expects(:hive_opts).with.returns(p2_opts = ['-i', mock().to_s])
        s1 = mock().to_s
        s2 = mock().to_s
        assert_equal [@hive_path, s1] + p1_opts + [s2] + p2_opts,
                     @klass.new([s1, p1, s2, p2]).command
      end
    end
  end
end
