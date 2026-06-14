require "test_helper"

class TestResource < Minitest::Test
  def test_build_resource_with_all_attributes
    res = SemanticCli::Resource.build("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName, :state, :blueprintId
      action("delete") { |item| "aws lightsail delete-instance --instance-name #{item[:id]}" }
      action("reboot") { |item| "aws lightsail reboot-instance --instance-name #{item[:id]}" }
    end

    assert_equal "instances", res.name
    assert_equal :instanceName, res.identity_field
    assert_equal [:instanceName, :state, :blueprintId], res.display_fields
    assert_equal "aws lightsail get-instances", res.list_command
    assert_equal 2, res.actions.size
    assert res.actions.key?("delete")
    assert res.actions.key?("reboot")
  end

  def test_action_build_command
    res = SemanticCli::Resource.build("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName
      action("delete") { |item| "aws lightsail delete-instance --instance-name #{item[:id]}" }
    end

    cmd = res.actions["delete"].build_command(id: "my-server")
    assert_equal "aws lightsail delete-instance --instance-name my-server", cmd
  end

  def test_resource_with_no_actions
    res = SemanticCli::Resource.build("buckets") do
      list { "aws s3 ls --output json" }
      id :bucketName
      display :bucketName
    end

    assert_equal "buckets", res.name
    assert_equal "aws s3 ls --output json", res.list_command
    assert_empty res.actions
  end

  def test_name_coerced_to_string
    res = SemanticCli::Resource.build(:instances) do
      list { "cmd" }
      id :name
      display :name
    end

    assert_equal "instances", res.name
  end

  def test_aliases
    res = SemanticCli::Resource.build("lightsail-instances", aliases: ["lightsail"]) do
      list { "aws lightsail get-instances" }
      id :name
      display :name
    end

    assert_equal "lightsail-instances", res.name
    assert_equal ["lightsail"], res.aliases
  end
end
