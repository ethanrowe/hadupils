class Hadupils::Extensions::HiveTest < Test::Unit::TestCase
  shared_context :provide_hive_ext do
    setup do
      @ext = Hadupils::Extensions::Hive.new(@tempdir.path)
    end
  end

  shared_context :hive_aux_jars_path_cases do
    should 'assemble hive_aux_jars_path from auxiliary_jars appropriately for use with HIVE_AUX_JARS_PATH env' do
      jars = [mock, mock, mock, mock].collect {|m| m.to_s}
      @ext.expects(:auxiliary_jars).with.returns(jars.collect {|j| "  #{j}  "})
      # Verifying whitespace trimming, as part of it.
      assert_equal jars.join(','), @ext.hive_aux_jars_path
    end
  end

  shared_context :empty_hiverc_cases do
    should 'have an empty hivercs list' do
      assert_equal [], @ext.hivercs
    end
  end

  shared_context :empty_auxiliary_cases do
    should 'have an empty auxiliary jars list' do
      assert_equal [], @ext.auxiliary_jars
    end
  end

  shared_context :valid_auxiliary_cases do
    should 'provide jars within aux-jars as the auxiliary_jars list' do
      assert_equal @aux_jars, @ext.auxiliary_jars
    end
  end

  shared_context :static_hiverc_cases do
    should 'have the hiverc path for the final entry in hivercs' do
      assert_equal @hiverc_file, @ext.hivercs[-1].hive_opts[1]
    end

    should 'have a static hiverc resource' do
      assert_equal '-i', @ext.hivercs[-1].hive_opts[0]
    end
  end

  shared_context :single_hiverc_cases do
    should 'have only a single hiverc in the hivercs list' do
      assert_equal 1, @ext.hivercs.length
    end
  end

  shared_context :dynamic_hiverc_cases do
    should 'have a hiverc with appropriate asset-oriented commands as the first entry in the hivercs' do
      File.open(@ext.hivercs[0].hive_opts[1], 'r') do |f|
        assert_equal @asset_commands, f.read
      end
    end

    should 'have a dynamic hiverc resource' do
      assert_equal '-i', @ext.hivercs[0].hive_opts[0]
    end
  end

  shared_context :has_auxiliary_path do
    setup do
      @aux = @tempdir.full_path('aux-jars')
      ::Dir.mkdir(@aux)
    end
  end

  shared_context :has_auxiliary_jars do
    setup do
      if @aux.nil?
        @aux = @tempdir.full_path('aux-jars')
        ::Dir.mkdir(@aux)
      end
      @aux_jars = %w(a b c).collect do |base|
        f = @tempdir.file(::File.join('aux-jars', "#{base}.jar"))
        f.close
        f.path
      end
      %w(tar.gz txt yaml).each do |extension|
        @tempdir.file(::File.join('aux-jars', "bogus.#{extension}"))
      end
    end
  end

  shared_context :has_hiverc_file do
    setup do
      f = @tempdir.file('hiverc')
      @hiverc_file = f.path
      f.close
    end
  end

  shared_context :has_assets do
    setup do
      @assets = %w{a.archive.tar.gz a.file.txt a.jar}.collect do |asset|
        f = @tempdir.file(asset)
        f.close
        f.path
      end

      @asset_commands = "ADD ARCHIVE #{@assets[0]};\n" +
                        "ADD FILE #{@assets[1]};\n" +
                        "ADD JAR #{@assets[2]};\n"
    end
  end

  tempdir_context Hadupils::Extensions::Hive do
    context 'with auxiliary jars' do
      provide_hive_ext
      hive_aux_jars_path_cases
    end

    context 'given an empty directory' do
      provide_hive_ext
      empty_hiverc_cases
      empty_auxiliary_cases
    end

    context 'given an empty aux-jars directory' do
      has_auxiliary_path
      provide_hive_ext
      empty_hiverc_cases
      empty_auxiliary_cases
    end

    context 'given a hiverc file' do
      has_hiverc_file
      provide_hive_ext
      empty_auxiliary_cases
      static_hiverc_cases
      single_hiverc_cases
    end

    context 'given assets' do
      has_assets

      context 'and nothing else' do
        provide_hive_ext
        empty_auxiliary_cases
        dynamic_hiverc_cases
        single_hiverc_cases
      end

      context 'and a hiverc file' do
        has_hiverc_file
        provide_hive_ext
        empty_auxiliary_cases
        dynamic_hiverc_cases
        static_hiverc_cases
      end
    end

    context 'given a directory with an aux-jars directory and jars' do
      has_auxiliary_jars

      context 'and nothing else' do
        provide_hive_ext
        empty_hiverc_cases
        valid_auxiliary_cases
      end

      context 'and assets' do
        has_assets
        provide_hive_ext
        valid_auxiliary_cases
        dynamic_hiverc_cases
        single_hiverc_cases
      end

      context 'and a hiverc file' do
        has_hiverc_file

        context 'and no assets' do
          provide_hive_ext
          static_hiverc_cases
          valid_auxiliary_cases
          single_hiverc_cases
        end

        context 'and assets' do
          has_assets
          provide_hive_ext
          dynamic_hiverc_cases
          static_hiverc_cases
          valid_auxiliary_cases
        end
      end
    end
  end

  tempdir_context Hadupils::Extensions::HiveSet do
    setup do
      @cls = Hadupils::Extensions::HiveSet
    end

    should 'have the dir path expanded as :path' do
      # Making the path relative demonstrates path expansion
      ::Dir.chdir(::File.dirname(@tempdir.path)) do
        assert_equal @tempdir.path,
                     @cls.new(::File.basename(@tempdir.path)).path
      end
    end

    should 'produce a Hadupils::Extensions::Hive per subdirectory' do
      ::Dir.mkdir(a = @tempdir.full_path('aye'))
      ::Dir.mkdir(b = @tempdir.full_path('bee'))
      ::Dir.mkdir(c = @tempdir.full_path('si'))

      # These should be ignored 'cause they ain't dirs
      @tempdir.file('foo.txt')
      @tempdir.file('blah.jar')
      @tempdir.file('garbage.tar.gz')

      expect = [a, b, c].collect {|path| [Hadupils::Extensions::Hive, path]}
      ext = @cls.new(@tempdir.path)
      assert_equal expect,
                   ext.members.collect {|member| [member.class, member.path]}
    end

    context 'with members' do
      setup do
        @member_a = mock
        @member_b = mock
        @cls.expects(:gather_member_extensions).with(@tempdir.path).returns(@members = [@member_a, @member_b])
        @ext = @cls.new @tempdir.path
      end

      hive_aux_jars_path_cases

      should 'base members list on :gather_member_extensions' do
        assert_equal @members, @ext.members
      end

      should 'produce the cumulative hivercs list from its members' do
        hivercs = @members.inject([]) do |expect, member|
          this_pair = [mock, mock]
          member.expects(:hivercs).with.returns(this_pair)
          expect + this_pair
        end

        assert_equal hivercs, @ext.hivercs
      end

      should 'produce the cumulative auxiliary_jars list from its members' do
        jarries = @members.inject([]) do |expect, member|
          jars = [mock, mock, mock].collect {|jar| jar.to_s}
          member.expects(:auxiliary_jars).with.returns(jars)
          expect + jars
        end

        assert_equal jarries, @ext.auxiliary_jars
      end
    end
  end
end
