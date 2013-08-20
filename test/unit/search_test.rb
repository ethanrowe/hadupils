class Hadupils::SearchTest < Test::Unit::TestCase
  tempdir_context 'find_from_dir' do
    setup do
      @module = Hadupils::Search
      @search_name = mock().to_s
    end

    should 'return nil if requested directory cannot be found' do
      assert_equal nil, @module.find_from_dir(@search_name, @tempdir.path)
    end

    should 'should find the directory when it is in the start dir' do
      p = @tempdir.full_path('blah')
      Dir.mkdir p
      assert_equal p, @module.find_from_dir('blah', @tempdir.path)
    end

    should 'find the directory when it is in a sibling of the start dir' do
      target = @tempdir.full_path('target-dir')
      start = @tempdir.full_path('start-dir')
      [target, start].each {|d| Dir.mkdir(d) }
      assert_equal target, @module.find_from_dir('target-dir', start)
    end

    should 'find the directory when it is above the start dir' do
      d = @tempdir.full_path('flickityflu')
      Dir.mkdir(d)
      assert_equal @tempdir.path,
                   @module.find_from_dir(File.basename(@tempdir.path), d)
    end
  end

  context 'find_from_pwd' do
    setup do
      @module = Hadupils::Search
      @pwd = ::Dir.pwd
      @target = mock()
    end

    should 'return the path found by find_from_dir for the pwd' do
      @module.expects(:find_from_dir).with(@target, @pwd).returns(result = mock())
      assert_equal result, @module.find_from_pwd(@target)
    end

    should 'return nil when given that by find_from_dir for the pwd' do
      @module.expects(:find_from_dir).with(@target, @pwd).returns(nil)
      assert_equal nil, @module.find_from_pwd(@target)
    end
  end

  context 'user_config' do
    setup do
      @module = Hadupils::Search
    end

    should 'use ~/conf by default' do
      assert_equal ::File.expand_path(::File.join('~', 'conf')),
                   @module.user_config
    end

    should 'be settable' do
      assert_equal true, @module.respond_to?(:user_config=)
    end
  end

  context 'hadoop_assets' do
    should 'search for directory specified by #hadoop_assets_name' do
      Hadupils::Search.expects(:hadoop_assets_name).with.returns(name = mock().to_s)
      Hadupils::Search.expects(:find_from_pwd).with(name).returns(dir = mock())
      assert_equal dir, Hadupils::Search.hadoop_assets
    end
  end

  context 'hadoop_assets_name' do
    should 'default to "hadoop-ext"' do
      assert_equal 'hadoop-ext', Hadupils::Search.hadoop_assets_name
    end

    should 'be settable' do
      assert_respond_to Hadupils::Search, :hadoop_assets_name=
    end
  end
end
