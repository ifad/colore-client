# frozen_string_literal: true

require 'pathname'
require 'byebug'
require 'simplecov'
require 'vcr'
require 'filemagic/ext'

SimpleCov.start

SPEC_BASE = Pathname.new(__dir__)

require 'colore-client'

def fixture(name)
  SPEC_BASE.join('fixtures', name)
end

VCR.configure do |c|
  c.cassette_library_dir = SPEC_BASE.join('fixtures/cassettes')
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |rspec|
  rspec.tty = true
  rspec.color = true
end
