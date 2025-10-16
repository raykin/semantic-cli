# frozen_string_literal: true

require "test_helper"

class TestSemanticCli < Minitest::Test
  def test_it_has_a_version_number
    refute_nil ::SemanticCli::VERSION
  end

  def test_dsl_integration
    dsl = SemanticCli::DSL.new
    dsl.define("echo") { |msg| "echo #{msg}" }
    assert_equal "echo hi", dsl.call("echo", "hi")
  end
end
