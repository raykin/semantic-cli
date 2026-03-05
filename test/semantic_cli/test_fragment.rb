#require_relative "test_helper"

class TestFragment < Minitest::Test
  def test_fragment_attributes
    frag = SemanticCli::Fragment.new("log", "nginx", "journalctl -u nginx -f")
    assert_equal "log", frag.name
    assert_equal "nginx", frag.arg
    assert_equal "journalctl -u nginx -f", frag.shell
  end
end
