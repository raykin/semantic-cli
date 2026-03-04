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

  def test_cmd_shorthand
    SemanticCli.reset!
    cmd "greet", "echo hello"
    assert_equal "echo hello", SemanticCli.dsl.call("greet")
  end

  def test_platform_helpers
    assert [true, false].include?(macos?)
    assert [true, false].include?(linux?)
    refute_equal macos?, linux?
  end
end
