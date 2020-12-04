require 'bundler/setup'
require 'grape'
require 'grape/instrumentation'
require 'signalfx_test_tracer'
require 'rack/test'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
