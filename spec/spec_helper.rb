# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"

require "rubocop/instance_variable_access"
require "rubocop/cop/instance_variable_access_cops"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
