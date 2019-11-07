Gem::Specification.new do |s|
  s.name = %q{trophonius}
  s.version = '1.0.10'
  s.authors = 'Kempen Automatisering'
  s.homepage = %q{https://github.com/Willem-Jan/Trophonius}
  s.date = %q{2019-10-03}
  s.summary = %q{Link between Ruby (on Rails) and FileMaker.}
  s.description = %q{An easy to use link between Ruby (on Rails) and FileMaker using the FileMaker Data-API.}
  s.files = Dir['lib/**/*.rb']
  s.license = 'MIT'
  s.require_paths = ['lib']

  s.add_runtime_dependency 'typhoeus', '~> 1.3'
  s.add_runtime_dependency 'redis', '~> 3.0'
  s.add_runtime_dependency 'activesupport', '~> 5.2'

  # s.add_development_dependency 'solargraph', '~> 0.32', ">= 0.32.0"

end
