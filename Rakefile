# frozen_string_literal: true

require 'rake'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'yard'
YARD::Rake::YardocTask.new

desc 'Default: run RuboCop and RSpec.'
task default: %i[rubocop spec]
