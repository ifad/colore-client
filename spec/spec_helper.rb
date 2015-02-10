require 'pathname'
require 'byebug'
require 'simplecov'
require 'vcr'
require 'filemagic/ext'

SimpleCov.start

SPEC_BASE = Pathname.new(__FILE__).realpath.parent

$: << SPEC_BASE.parent + 'lib'
require 'colore-client'

def fixture name
  SPEC_BASE + 'fixtures' + name
end

VCR.configure do |c|
  c.cassette_library_dir = (SPEC_BASE + 'fixtures' + 'cassettes').to_s
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec::configure do |rspec|
  rspec.tty = true
  rspec.color = true
end
