# frozen_string_literal: true

require File.expand_path('lib/colore/client/version', __dir__)

Gem::Specification.new do |spec|
  spec.name           = 'colore-client'
  spec.version        = Colore::Client::VERSION
  spec.authors        = ['Joe Blackman']
  spec.email          = ['j.blackman@ifad.org']
  spec.description    = 'Ruby client to consume Colore services'
  spec.summary        = 'Ruby client to consume Colore services'

  spec.homepage       = 'https://github.com/ifad/colore-client'
  spec.license       = 'MIT'

  spec.files         = Dir['{bin/*,lib/**/*.rb,LICENSE,README.md}']
  spec.require_paths = ['lib']

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/ifad/colore-client/issues',
    'homepage_uri' => 'https://github.com/ifad/colore-client',
    'source_code_uri' => 'https://github.com/ifad/colore-client',
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'faraday', '>= 2.12'
end
