#require_relative "test_helper"

class TestFragment < Minitest::Test
  def test_fragment_attributes
    frag = SemanticCli::Fragment.new("log", "v2ray", "journalctl -u v2ray -f")
    assert_equal "log", frag.name
    assert_equal "v2ray", frag.arg
    assert_equal "journalctl -u v2ray -f", frag.shell
  end
end
