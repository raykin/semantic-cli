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

  def test_execute_resource_list_then_action
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\",\"state\":\"running\"},{\"name\":\"db-1\",\"state\":\"stopped\"}]'" }
      id :name
      display :name, :state
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1", "state" => "running"}, "delete")
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    out, _ = capture_io { runner.execute(%w[instances]) }
    assert_match(/→ Running: echo deleting web-1/, out)
  end

  def test_execute_resource_direct_action_skips_action_picker
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\",\"state\":\"running\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1", "state" => "running"})
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    out, _ = capture_io { runner.execute(%w[instances delete]) }
    assert_match(/→ Running: echo deleting web-1/, out)
    refute picker.action_called
  end

  def test_execute_with_profile_setting
    out, _ = capture_io { @runner.execute(%w[p:raykin-cli echo hi]) }
    assert_match(/→ Running: export AWS_PROFILE=raykin-cli && echo hi/, out)
  end

  def test_execute_resource_with_profile
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\",\"state\":\"running\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1", "state" => "running"})
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    out, _ = capture_io { runner.execute(%w[p:raykin-cli instances delete]) }
    assert_match(/→ Running: export AWS_PROFILE=raykin-cli && echo deleting web-1/, out)
  end

  def test_resource_prints_context
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1"}, "delete")
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    out, _ = capture_io { runner.execute(%w[p:myprofile r:us-west-2 instances]) }
    assert_match(/Loading instances \(profile: myprofile, region: us-west-2\)/, out)
  end

  def test_resource_prints_default_context
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1"}, "delete")
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    out, _ = capture_io { runner.execute(%w[instances]) }
    assert_match(/Loading instances \(profile: default, all regions\)/, out)
  end

  def test_resource_command_failure_prints_error
    @dsl.define_resource("instances") do
      list { "false" }
      id :name
      display :name
    end

    runner = SemanticCli::Runner.new(@dsl)
    _, err = capture_io { runner.execute(%w[instances]) }
    assert_match(/Command failed/, err)
  end

  def test_debug_prints_list_command
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1"}, "delete")
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    ENV["DEBUG"] = "true"
    _, err = capture_io { runner.execute(%w[instances]) }
    ENV.delete("DEBUG")

    assert_match(/\[debug\] list_cmd:/, err)
    assert_match(/\[debug\] response:/, err)
  end

  def test_no_debug_output_by_default
    @dsl.define_resource("instances") do
      list { "echo '[{\"name\":\"web-1\"}]'" }
      id :name
      display :name
      action("delete") { |item| "echo deleting #{item["name"]}" }
    end

    picker = MockPicker.new({"name" => "web-1"}, "delete")
    runner = SemanticCli::Runner.new(@dsl, picker: picker)

    _, err = capture_io { runner.execute(%w[instances]) }
    refute_match(/\[debug\]/, err)
  end

  class MockPicker
    attr_reader :action_called

    def initialize(item, action_name = nil)
      @item = item
      @action_name = action_name
      @action_called = false
    end

    def print_info(items, display_fields:); end

    def select_item(items, display_fields:, id_field:)
      @item
    end

    def select_action(actions)
      @action_called = true
      @action_name
    end
  end
end
