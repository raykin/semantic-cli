require "test_helper"

class TestRunner < Minitest::Test
  def setup
    @dsl = SemanticCli::DSL.new
    @dsl.define("echo") { |msg| "echo #{msg}" }
    @runner = SemanticCli::Runner.new(@dsl)
  end

  def test_execute_with_help
    @dsl.define("") { "Examples:\n  echo hi" }
    out, _ = capture_io { @runner.execute([]) }
    assert_match(/Examples:/, out)
  end

  def test_execute_with_command
    out, _ = capture_io { @runner.execute(%w[echo hi]) }
    assert_match(/→ Running: echo hi/, out)
  end
end
