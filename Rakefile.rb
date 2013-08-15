require 'rake'
require 'rake/testtask'
require 'rake/clean'

CLOBBER.include('hadupils-*.gem')

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
  t.libs = ['test', 'lib']
  # This should initialize the environment properly.
  t.ruby_opts << '-rhadupil_test_setup'
end

