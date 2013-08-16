class Hadupils::ExtensionsTest < Test::Unit::TestCase
  context Hadupils::Extensions::Base do
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
    end

    context 'dynamic wrapper' do
      setup do
        @klass = Hadupils::Extensions::HiveRC::Dynamic
      end

      should 'use Tempfile for its default file_handler' do
        assert_same ::Tempfile, @klass.file_handler
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
          expect = lines.join('\n') + '\n'
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
            expected = @asset_lines.join('\n') + '\n'
            @hiverc.write(@assets)
            assert_equal expected, @file.read
          end

          should 'handle intermingled text lines' do
            text_lines = ['some line one', 'some line two']
            [@assets, @asset_lines].each do |ary|
              ary.insert(2, text_lines[1])
              ary.insert(1, text_lines[0])
            end
            expected = @asset_lines.join('\n') + '\n'
            @hiverc.write(@assets)
            assert_equal expected, @file.read
          end
        end
      end
    end
  end
end
