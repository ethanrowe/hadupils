class Hadupils::Extensions::HiveTest < Test::Unit::TestCase
  shared_context :provide_hive_ext do
    setup do
      @ext = Hadupils::Extensions::Hive.new(@tempdir.path)
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
end
