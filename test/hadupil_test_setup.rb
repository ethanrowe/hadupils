require 'bundler'
Bundler.setup
require 'test/unit'
require 'shoulda-context'
require 'mocha/setup'
require 'tempfile'
require 'pathname'
require 'hadupils'

# Add tempdir niceties to Test::Unit::TestCase
# on top of the shoulda-context stuff.
class Test::Unit::TestCase
  class DirWrapper
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def full_path(path)
      ::File.expand_path(::File.join(@path, path))
    end

    def file(path)
      path = full_path(path)
      if block_given?
        ::File.open(path, 'w') do |f|
          yield f
        end
      else
        ::File.new(path, 'w')
      end
    end
  end

  def self.tempdir_context(name, &block)
    context name do
      setup do
        @tempdir = Test::Unit::TestCase::DirWrapper.new(::Pathname.new(::File.expand_path(::Dir.mktmpdir)).realpath.to_s)
      end

      teardown do
        FileUtils.remove_entry @tempdir.path
      end

      # Instance_eval instead of simple yield to ensure it happens in the Context object
      # and not in the test case subclass.
      instance_eval &block
    end
  end

  # Lets us define shared bits of shoulda context (setup blocks, tests,
  # subcontexts, etc.) in a declarative manner; installs a singleton method
  # :name into the calling class, that when invoked will eval the given
  # block in the current Shoulda::Context::Context.
  # You can then simply call :name in any arbitrary context in order to
  # make use of the shared stuff within that context.
  def self.shared_context(name, &block)
    define_singleton_method name do
      Shoulda::Context.current_context.instance_eval &block
    end
  end
end
