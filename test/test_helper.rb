# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "op_credentials"

require "minitest/autorun"
require "mocha/minitest"
require "minitest/pride"

# Mock Rails environment for testing
class MockRailsEnv
  def initialize
    @env = "test"
  end

  def production?
    @env == "production"
  end

  def staging?
    @env == "staging"
  end

  def development?
    @env == "development"
  end

  def test?
    @env == "test"
  end

  def local?
    ["development", "test"].include?(@env)
  end
end

# Set up Rails mock
module Rails
  def self.env
    @env ||= MockRailsEnv.new
  end

  def self.const_defined?(const_name)
    false
  end

  def self.application
    @application ||= Object.new
  end
end
