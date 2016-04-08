Gem::Specification.new do |gem|
  gem.name           = 'colore-client'
  gem.version        = '0.2.0'
  gem.authors        = [ 'Joe Blackman' ]
  gem.email          = [ 'j.blackman@ifad.org' ]
  gem.description    = %q(Ruby client to consume Colore services)
  gem.summary        = %q(Ruby client to consume Colore services)
  gem.homepage       = ''

  gem.add_dependency 'rest-client', '>=1.7.2'
  gem.add_dependency 'hashugar', '>= 1.0.0'

  gem.add_development_dependency 'rspec',        '>= 3.2.0'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'webmock'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'byebug'
  gem.add_development_dependency 'ruby-filemagic'

  gem.files          = `git ls-files`.split($/)
  gem.test_files     = gem.files.grep %r[^(test|spec|features)]
  gem.require_paths  = ['lib']
end
