require "test_helper"

class TestFragment < Minitest::Test
  def test_fragment_attributes
    frag = SemanticCli::Fragment.new("log", "nginx", "journalctl -u nginx -f")
    assert_equal "log", frag.name
    assert_equal "nginx", frag.arg
    assert_equal "journalctl -u nginx -f", frag.shell
  end

  def test_resource_fragment_for_list
    resource = SemanticCli::Resource.build("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName
    end

    frag = SemanticCli::ResourceFragment.new("instances", resource, nil)
    assert_equal "instances", frag.name
    assert_equal resource, frag.resource
    assert_nil frag.action_name
  end

  def test_resource_fragment_for_action
    resource = SemanticCli::Resource.build("instances") do
      list { "aws lightsail get-instances" }
      id :instanceName
      display :instanceName
      action("delete") { |item| "aws lightsail delete-instance --instance-name #{item[:id]}" }
    end

    frag = SemanticCli::ResourceFragment.new("instances", resource, "delete")
    assert_equal "instances", frag.name
    assert_equal "delete", frag.action_name
    assert_equal resource, frag.resource
  end
end
