# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'trophonius'
  s.version = '1.4.4.4'
  s.authors = 'Kempen Automatisering'
  s.homepage = 'https://github.com/Willem-Jan/Trophonius'
  s.summary = 'Link between Ruby (on Rails) and FileMaker.'
  s.description = 'A lightweight, easy to use link between Ruby (on Rails) and FileMaker using the FileMaker Data-API.'
  s.files = Dir['lib/**/*.rb']
  s.license = 'MIT'
  s.require_paths = %w[lib]

  s.add_runtime_dependency 'redis', '~> 4.0'
  s.add_runtime_dependency 'typhoeus', '~> 1.3'
  s.add_dependency 'activesupport', '>= 7.0' # , '<= 6.x'

  # s.add_development_dependency 'solargraph', '~> 0.32', ">= 0.32.0"
  s.metadata['rubygems_mfa_required'] = 'true'
end
