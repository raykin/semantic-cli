require "test_helper"

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

  def test_define_resource
    @dsl.define_resource("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName, :state
      action("delete") { |item| "delete #{item[:id]}" }
    end

    assert @dsl.resource?("instances")
    refute @dsl.resource?("buckets")

    res = @dsl.get_resource("instances")
    assert_equal "instances", res.name
    assert_equal :instanceName, res.identity_field
    assert_equal [:instanceName, :state], res.display_fields
  end

  def test_resource_coexists_with_functions
    @dsl.define("hello") { "echo hi" }
    @dsl.define_resource("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName
    end

    assert @dsl.exists?("hello")
    assert @dsl.resource?("instances")
    refute @dsl.exists?("instances")
    refute @dsl.resource?("hello")
  end

  def test_set_and_get
    @dsl.set(:profile, "production")
    assert_equal "production", @dsl.get(:profile)
  end

  def test_env_prefix_with_profile
    @dsl.set(:profile, "production")
    assert_equal "export AWS_PROFILE=production && ", @dsl.env_prefix
  end

  def test_env_prefix_with_profile_and_region
    @dsl.set(:profile, "production")
    @dsl.set(:region, "us-west-2")
    assert_equal "export AWS_PROFILE=production && export AWS_REGION=us-west-2 && ", @dsl.env_prefix
  end

  def test_env_prefix_empty_when_no_settings
    assert_equal "", @dsl.env_prefix
  end

  def test_runtime_setting_overrides_script_setting
    @dsl.set(:profile, "default")
    @dsl.set(:profile, "raykin-cli", runtime: true)
    assert_equal "raykin-cli", @dsl.get(:profile)
  end

  def test_script_setting_used_when_no_runtime
    @dsl.set(:profile, "default")
    assert_equal "default", @dsl.get(:profile)
  end

  def test_resource_alias_lookup
    @dsl.define_resource("lightsail-instances", aliases: ["lightsail"]) do
      list { "aws lightsail get-instances" }
      id :name
      display :name
    end

    assert @dsl.resource?("lightsail-instances")
    assert @dsl.resource?("lightsail")
    assert_equal @dsl.get_resource("lightsail-instances"), @dsl.get_resource("lightsail")
  end
end
