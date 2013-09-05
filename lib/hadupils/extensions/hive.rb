module Hadupils::Extensions

  # Hive-targeted extensions derived from filesystem layout
  #
  # = Concept
  # 
  # There are a few ways to "extend" one's hive session:
  #
  # * Adding files, archives, jars to it (+ADD ...+).
  # * Setting variables and whatnot (+SET ...+).
  # * Registering your own UDFS.
  # * Specifying paths to jars to make available within the session's
  #   classpath (+HIVE_AUX_JARS_PATH+ env. var.).
  #
  # All of these things can be done through the use of initialization
  # files (via hive's +-i+ option), except for the auxiliary jar libs
  # environment variable (which is.... wait for it... in the environment).
  #
  # This class provides an abstraction to enable the following:
  # * lay your files out according to its expectations
  # * wrap that layout with an instance of this class
  # * it'll give an interface for accessing initialization files (#hivercs)
  #   that make the stuff available in a hive session
  # * it'll dynamically assemble the initialization file necessary to
  #   ensure appropriate assets are made available in the session
  # * if you provide your own initialization file in the expected place,
  #   it'll ensure that the dynamic stuff is applied _first_ and the static
  #   one second, such that your static one can assume the neighboring
  #   assets are already in the session.
  # * it'll give you a list of jars to make available as auxiliary_jars in the
  #   session based on contents of +aux-jars+.
  # 
  # You lay it down, the object makes sense of it, nothing other than
  # file organization required.
  #
  # = Filesystem Layout
  #
  # Suppose you have the following stuff (denoting symlinks with +->+):
  #
  #     /etc/foo/
  #         an.archive.tar.gz
  #         another.archive.tar.gz
  #         aux-jars/
  #             aux-only.jar
  #             ignored.archive.tar.gz
  #             ignored.file.txt
  #             jarry.jar -> ../jarry.jar
  #         dist-only.jar
  #         hiverc
  #         jarry.jar
  #         textie.txt
  #         yummy.yaml
  # 
  # Now you create an instance:
  #
  #     ext = Hadupils::Extensions::Hive.new('/etc/foo')
  #
  # You could get the hive command-line options for using this stuff
  # via:
  #
  #     ext.hivercs
  #
  # It'll give you objects for two initialization files:
  # 1. A dynamic one that has the appropriate commands for adding
  #    +an.archive.tar.gz+, +another.archive.tar.gz+, +dist-only.jar+,
  #    +jarry.jar+, +textie.txt+, and +yummy.yaml+ to the session.
  # 2. The +hiverc+ one that's in there.
  #
  # And, the +ext.auxiliary_jars+ accessor will return a list of paths to
  # the jars (_only_ the jars) contained within the +aux-jars+ path;
  # a caller to hive would use this to construct the +HIVE_AUX_JARS_PATH+
  # variable.
  #
  # Notice that +jarry.jar+ is common to the distributed usage (it'll be
  # added to the session and associated distributed cache) and to the
  # auxiliary path.  That's because it appears in the main directory and
  # in the +aux-jars+ subdirectory.  There's nothing magical about the
  # use of a symlink; that just saves disk space.  10 MB ought be enough
  # for anyone.
  #
  # If there was no +hiverc+ file, then you would only get the
  # initialization file object for the loading of assets in the main
  # directory.  Conversely, if there were no such assets, but there was
  # a +hiverc+ file, you would get only the object for that file.  If
  # neither were present, the #hivercs will be an empty list.
  #
  # If there is no +aux-jars+ directory, or that directory has no jars,
  # the +ext.auxiliary_jars+ would be an empty list.  Only jars will be included
  # in that list; files without a +.jar+ extension will be ignored.
  #
  class Hive
    AUX_PATH = 'aux-jars'
    HIVERC_PATH = 'hiverc'

    attr_reader :auxiliary_jars
    attr_reader :path

    def initialize(path)
      @path = ::File.expand_path(path)
      @auxiliary_jars = self.class.find_auxiliary_jars(@path)
      @dynamic_ext = self.class.assemble_dynamic_extension(@path)
      @static_ext = self.class.assemble_static_extension(@path)
    end

    def hivercs
      dynamic_hivercs + static_hivercs
    end

    def dynamic_hivercs
      if @dynamic_ext.assets.length > 0
        @dynamic_ext.hivercs
      else
        []
      end
    end
    
    def static_hivercs
      @static_ext.hivercs
    end

    def self.find_auxiliary_jars(path)
      target = ::File.join(path, AUX_PATH)
      if ::File.directory? target
        jars = Hadupils::Assets.assets_in(target).find_all do |asset|
          asset.kind_of? Hadupils::Assets::Jar
        end
        jars.collect {|asset| asset.path}
      else
        []
      end
    end

    def self.assemble_dynamic_extension(path)
      Flat.new(path) do
        assets do |list|
          list.reject {|asset| [AUX_PATH, HIVERC_PATH].include? asset.name }
        end
      end
    end

    def self.assemble_static_extension(path)
      Static.new(path)
    end
  end
end
