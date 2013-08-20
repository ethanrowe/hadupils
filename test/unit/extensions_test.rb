class Hadupils::ExtensionsTest < Test::Unit::TestCase
  context Hadupils::Extensions::Base do
    context 'initialization with nil path' do
      should 'have nil as the path' do
        ext = Hadupils::Extensions::Base.new(nil)
        assert_equal nil, ext.path
      end
    end

    context 'initialization' do
      setup do
        @path = mock()
        @expanded_path = mock()
        @assets = mock()
        ::File.expects(:expand_path).with(@path).returns(@expanded_path)
      end

      should 'expand the given directory into :path' do
        Hadupils::Extensions::Base.stubs(:gather_assets).returns(@assets)
        assert_equal @expanded_path, Hadupils::Extensions::Base.new(@path).path
      end

      should "gather the expanded directory's assets" do
        Hadupils::Extensions::Base.expects(:gather_assets).with(@expanded_path).returns(@assets)
        assert_equal @assets, Hadupils::Extensions::Base.new(@path).assets
      end

      should "allow manipulation of assets post-expansion" do
        Hadupils::Extensions::Base.stubs(:gather_assets).returns(@assets)
        extra = mock()
        ext = Hadupils::Extensions::Base.new(@path) do
          assets do |items|
            # We're just adding the new stuff to the original stuff
            [items, extra]
          end
        end
        # If the above assets block was applied, we'll see the additional
        # item there.
        assert_equal [@assets, extra], ext.assets
      end

      should 'have an empty hivercs list' do
        Hadupils::Extensions::Base.stubs(:gather_assets).returns(@assets)
        assert_equal [], Hadupils::Extensions::Base.new(@path).hivercs
      end
    end

    context 'gather_assets' do
      should 'assemble assets with Hadupils::Assets.assets_in' do
        path = mock()
        result = mock()
        Hadupils::Assets.expects(:assets_in).with(path).returns(result)
        assert_equal result, Hadupils::Extensions::Base.gather_assets(path)
      end

      should 'allow manipulation of assets' do
      end

      should 'produce empty list for a nil path' do
        Hadupils::Assets.expects(:assets_in).never
        assert_equal [], Hadupils::Extensions::Base.gather_assets(nil)
      end
    end
  end

  context 'a hiverc' do
    context 'static wrapper' do
      setup do
        @klass = Hadupils::Extensions::HiveRC::Static
      end

      should 'expand the given path into its path attr' do
        path = 'foo/bar/blah'
        assert_equal ::File.expand_path(path), @klass.new(path).path
      end

      should 'provide a close no-op' do
        assert_respond_to @klass.new('blah'), :close
      end

      should 'know how to convert to #hive_opts' do
        path = 'some/awesome/path'
        assert_equal ['-i', ::File.expand_path(path)],
                     @klass.new(path).hive_opts
      end
    end

    context 'dynamic wrapper' do
      setup do
        @klass = Hadupils::Extensions::HiveRC::Dynamic
      end

      should 'use Tempfile for its default file_handler' do
        assert_same ::Tempfile, @klass.file_handler
      end

      should 'know how to convert to #hive_opts' do
        obj = @klass.new
        obj.stubs(:path).returns(path = mock())
        assert_equal ['-i', obj.path],
                     obj.hive_opts
      end

      context 'internal file' do
        setup do
          @klass.expects(:file_handler).with().returns(@handler = mock())
          @handler.expects(:new).with('hadupils-hiverc').returns(@file = mock())
        end

        should "come from the class' file_handler" do
          assert_equal @file, @klass.new.file
        end

        should 'provide the path' do
          @file.stubs(:path).returns(path = mock())
          ::File.stubs(:expand_path).with(path).returns(expanded = mock())
          assert_equal expanded, @klass.new.path
        end

        should 'close the file on close()' do
          @file.expects(:close).with()
          @klass.new.close
        end
      end

      context 'write operation' do
        setup do
          @hiverc = @klass.new
          @file = File.open(@hiverc.path, 'r')
        end

        teardown do
          @file.close
          @hiverc.close
        end

        should 'handle simple text lines' do
          lines = ['some stuff!', 'but what about...', 'this and this!?!']
          @hiverc.write(lines)
          expect = lines.join("\n") + "\n"
          assert_equal expect, @file.read
        end

        context 'given assets' do
          setup do
            @asset_lines = ['ADD FILE foofoo;',
                            'ADD ARCHIVE bloobloo.tar.gz;',
                            'ADD JAR jarjar.jar;']
            @assets = @asset_lines.collect do |line|
              m = mock()
              m.stubs(:hiverc_command).with.returns(line)
              m
            end
          end

          should 'use their hiverc_command for lines' do
            expected = @asset_lines.join("\n") + "\n"
            @hiverc.write(@assets)
            assert_equal expected, @file.read
          end

          should 'handle intermingled text lines' do
            text_lines = ['some line one', 'some line two']
            [@assets, @asset_lines].each do |ary|
              ary.insert(2, text_lines[1])
              ary.insert(1, text_lines[0])
            end
            expected = @asset_lines.join("\n") + "\n"
            @hiverc.write(@assets)
            assert_equal expected, @file.read
          end
        end
      end
    end
  end

  context Hadupils::Extensions::Flat do
    setup do
      @klass = Hadupils::Extensions::Flat
    end

    should 'extend Hadupils::Extensions::Base' do
      # I usually hate testing this sort of thing, but I want to quickly claim
      # that @klass has the basic behaviors and focus on what's special about it.
      assert @klass.ancestors.include? Hadupils::Extensions::Base
    end

    tempdir_context 'for realz' do
      setup do
        @tempdir.file(@file = 'a.file')
        @tempdir.file(@jar = 'a.jar')
        @tempdir.file(@archive = 'an.archive.tar.gz')
        @file_line = "ADD FILE #{@tempdir.full_path(@file)};"
        @jar_line = "ADD JAR #{@tempdir.full_path(@jar)};"
        @archive_line = "ADD ARCHIVE #{@tempdir.full_path(@archive)};"
      end

      should 'produce only one hiverc' do
        hivercs = @klass.new(@tempdir.path).hivercs
        assert_equal 1, hivercs.size
      end

      should 'produce a hiverc for the expected assets' do
        hivercs = @klass.new(@tempdir.path).hivercs
        expected = "#{@file_line}\n#{@jar_line}\n#{@archive_line}\n"
        File.open(hivercs[0].path, 'r') do |f|
          assert_equal expected, f.read
        end
      end

      should 'produce a hiverc of a dynamic type' do
        # This is because I had a bug and was giving the hiverc File
        # object instead of the dynamic hiverc wrapper object.
        # Thus it blew up later on.
        hivercs = @klass.new(@tempdir.path).hivercs
        assert_kind_of Hadupils::Extensions::HiveRC::Dynamic, hivercs[0]
      end

      should 'allow manipulation of hiverc items' do
        extension = @klass.new(@tempdir.path) do
          hiverc do |assets|
            assets.insert(1, 'INSERT SOME TEXT HERE')
            assets << 'FINAL LINE!'
          end
        end
        expected = "#{@file_line}\n" +
                   "INSERT SOME TEXT HERE\n" +
                   "#{@jar_line}\n#{@archive_line}\n" +
                   "FINAL LINE!\n"
        File.open(extension.hivercs[0].path, 'r') do |f|
          assert_equal expected, f.read
        end
      end
    end
  end

  tempdir_context Hadupils::Extensions::Static do
    setup do
      @extension = Hadupils::Extensions::Static.new(@tempdir.path)
    end

    should 'have an empty list of assets from gather_assets' do
      # These would ordinarily become assets in a dynamic extension.
      @tempdir.file('some.jar')
      @tempdir.file('some.tar.gz')
      @tempdir.file('some.yaml')
      # but not in this one.
      assert_equal [], Hadupils::Extensions::Static.new(@tempdir.path).assets
    end

    should 'have an empty hivercs list when no hiverc file exists' do
      assert_equal [], @extension.hivercs
    end

    context 'with a hiverc file' do
      setup do
        @hiverc = @tempdir.file('hiverc')
      end

      should 'have a static HiveRC instance in its hivercs list when a hiverc file exists' do
        assert_equal [[Hadupils::Extensions::HiveRC::Static, @hiverc.path]],
                     @extension.hivercs.collect {|h| [h.class, h.path] }
      end
    end
  end
end
