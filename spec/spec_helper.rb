require 'bundler/setup'
require 'coveralls'
Coveralls.wear!
require 'remote_ruby'

require_relative 'integration/config'

Bundler.require(:development, :test)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_including(focus: true)
  config.run_all_when_everything_filtered = true
end
