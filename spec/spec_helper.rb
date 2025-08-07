# frozen_string_literal: true

require 'rspec'
require 'webmock/rspec'

# Configure WebMock to block all external HTTP requests
WebMock.disable_net_connect!(allow_localhost: true)

# Load the application
require_relative '../lib/github_repo_fetcher'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'tmp/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc'

  # Exclude e2e tests by default - they're slow and require external dependencies
  config.filter_run_excluding :e2e unless ENV['RUN_E2E']

  config.order = :random
  Kernel.srand config.seed
end
