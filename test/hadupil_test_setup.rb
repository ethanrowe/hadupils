require 'bundler'
Bundler.setup
require 'test/unit'
require 'shoulda-context'
require 'mocha/setup'
require 'tempfile'
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
        @tempdir = Test::Unit::TestCase::DirWrapper.new(::File.expand_path(::Dir.mktmpdir))
      end

      teardown do
        FileUtils.remove_entry @tempdir.path
      end

      # Instance_eval instead of simple yield to ensure it happens in the Context object
      # and not in the test case subclass.
      instance_eval &block
    end
  end
end
