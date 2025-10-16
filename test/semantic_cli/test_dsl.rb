#require_relative "test_helper"

class TestDSL < Minitest::Test
  def setup
    @dsl = SemanticCli::DSL.new
  end

  def test_define_and_call_without_arg
    @dsl.define("hello") { "echo hi" }
    assert_equal "echo hi", @dsl.call("hello")
  end

  def test_define_and_call_with_arg
    @dsl.define("say") { |word| "echo #{word}" }
    assert_equal "echo world", @dsl.call("say", "world")
  end

  def test_exists_and_expects_arg
    @dsl.define("foo") { |x| "echo #{x}" }
    assert @dsl.exists?("foo")
    assert @dsl.expects_arg?("foo")
  end
end
