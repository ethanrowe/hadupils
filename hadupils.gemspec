require 'rake'
Gem::Specification.new do |s|
  s.name        = 'hadupils'
  s.version     = '0.7.0'
  s.email       = 'ethan@the-rowes.com'
  s.author      = 'Ethan Rowe'
  s.date        = '2013-10-28'
  s.platform    = Gem::Platform::RUBY
  s.description = 'Provides utilities for dynamic hadoop client environment configuration'
  s.summary     = s.description
  s.homepage    = 'http://github.com/ethanrowe/hadupils'
  s.license     = 'MIT'

  s.files       = FileList['lib/**/*.rb', 'test/**/*.rb', 'bin/*', '[A-Z]*'].to_a
  s.executables << 'hadupils'

  s.add_dependency('uuid', '~> 2.3.0')

  s.add_development_dependency('bundler', '~> 1.6.2')
  s.add_development_dependency('mocha')
  s.add_development_dependency('rake', '~> 10.1.0')
  s.add_development_dependency('shoulda-context')
end
