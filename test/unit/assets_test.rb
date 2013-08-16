class AssetsTest < Test::Unit::TestCase
  context 'a file' do
    setup do
      @path = '/foo/bar/some_file.blah'
      @asset = Hadupils::Assets::File.new(@path)
    end

    should 'have a path' do
      assert_equal @path, @asset.path
    end

    should 'have a name' do
      assert_equal ::File.basename(@path), @asset.name
    end

    should 'have an ADD FILE hiverc command' do
      assert_equal "ADD FILE #{@path};", @asset.hiverc_command
    end

    should 'not be hidden' do
      assert_equal false, @asset.hidden?
    end
  end

  context 'a jar' do
    setup do
      @path = '/blah/blargh/../foo/blee/something.jar'
      @asset = Hadupils::Assets::Jar.new(@path)
    end

    should 'have a path' do
      assert_equal @path, @asset.path
    end

    should 'have a name' do
      assert_equal ::File.basename(@path), @asset.name
    end

    should 'have an ADD JAR hiverc command' do
      assert_equal "ADD JAR #{@path};", @asset.hiverc_command
    end

    should 'not be hidden' do
      assert_equal false, @asset.hidden?
    end
  end

  context 'a tarball' do
    setup do
      @path = '/blah/blargh/../foo/blee/something.jar'
      @asset = Hadupils::Assets::Archive.new(@path)
    end

    should 'have a path' do
      assert_equal @path, @asset.path
    end

    should 'have a name' do
      assert_equal ::File.basename(@path), @asset.name
    end

    should 'have an ADD ARCHIVE hiverc command' do
      assert_equal "ADD ARCHIVE #{@path};", @asset.hiverc_command
    end

    should 'not be hidden' do
      assert_equal false, @asset.hidden?
    end
  end

  context 'a hidden file' do
    should 'have a hidden File asset' do
    end

    should 'have a hidden Archive asset' do
    end

    should 'have a hidden Jar asset' do
    end
  end

  context 'asset_for' do
    context 'given a file of no particular extension' do
      setup do
        @path = '/some/special/file.path'
        @asset = Hadupils::Assets.asset_for(@path)
      end

      should 'produce a Hadupils::Assets::File' do
        assert_same Hadupils::Assets::File, @asset.class
      end

      should 'pass the path through' do
        assert_equal @path, @asset.path
      end
    end

    context 'given a file with a .jar extension' do
      setup do
        @path = '/some/great/magical-1.7.9.jar'
        @asset = Hadupils::Assets.asset_for(@path)
      end

      should 'product a Hadupils::Assets::Jar' do
        assert_same Hadupils::Assets::Jar, @asset.class
      end

      should 'pass the path through' do
        assert_equal @path, @asset.path
      end
    end

    context 'given a file with a .tar.gz extension' do
      setup do
        @path = '/some/freaking/awesome.tar.gz'
        @asset = Hadupils::Assets.asset_for(@path)
      end

      should 'produce a Hadupils::Assets::Archive' do
        assert_same Hadupils::Assets::Archive, @asset.class
      end

      should 'pass the path through' do
        assert_equal @path, @asset.path
      end
    end
  end

  tempdir_context 'a directory with files' do
    setup do
      @tempdir.file(@archive = 'an-archive.tar.gz')
      @tempdir.file(@jar = 'jarry.jar')
      @tempdir.file(@file = 'some.yaml')
      @matches = {@archive => Hadupils::Assets::Archive,
                  @jar     => Hadupils::Assets::Jar,
                  @file    => Hadupils::Assets::File}
    end

    context 'given to Hadupils::Assets.foreach_asset_in' do
      setup do
        @received = []
        Hadupils::Assets.foreach_asset_in(@tempdir.path) {|a| @received << a}
      end

      should 'get assets in lexicographic order' do
        assert_equal @matches.keys.sort, (@received.collect {|a| a.name})
      end

      should 'get assets of appropriate type' do
        type_map = @received.inject({}) {|hash, asset| hash[asset.name] = asset.class; hash}
        assert_equal @matches, type_map
      end

      should 'get assets with expanded paths' do
        path_map = @received.inject({}) {|hash, asset| hash[asset.name] = asset.path; hash}
        expected = @matches.keys.inject({}) do |hash, name|
          hash[name] = @tempdir.full_path(name)
          hash
        end
        assert_equal expected, path_map
      end
    end
  end
end
