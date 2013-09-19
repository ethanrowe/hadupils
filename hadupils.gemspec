require 'rake'
Gem::Specification.new do |s|
  s.name        = 'hadupils'
  s.version     = '0.4.0'
  s.email       = 'ethan@the-rowes.com'
  s.author      = 'Ethan Rowe'
  s.date        = '2013-08-22'
  s.platform    = Gem::Platform::RUBY
  s.description = 'Provides utilities for dynamic hadoop client environment configuration'
  s.summary     = s.description
  s.homepage    = 'http://github.com/ethanrowe/hadupils'
  s.license     = 'MIT'

  s.files = FileList['lib/**/*.rb', 'test/**/*.rb', 'bin/*', '[A-Z]*'].to_a
  s.executables << 'hadupils'

  s.add_development_dependency('bundler')
  s.add_development_dependency('mocha')
  s.add_development_dependency('rake')
  s.add_development_dependency('shoulda-context')
end
