require 'rake'
Gem::Specification.new do |s|
  s.name        = 'hadupils'
  s.version     = '0.0.1'
  s.email       = 'ethan@the-rowes.com'
  s.author      = 'Ethan Rowe'
  s.date        = '2013-08-15'
  s.platform    = Gem::Platform::RUBY
  s.description = 'Provides utilities for dynamic hadoop client environment configuration'
  s.summary     = s.description
  s.homepage    = 'http://github.com/ethanrowe/hadupils'
  s.license     = 'MIT'

  s.files = FileList['lib/**/*.rb'].to_a
end
