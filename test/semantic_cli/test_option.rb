class TestOption < Minitest::Test
  def test_kv_function
    opt = SemanticCli::Option.new("max:5")
    assert_equal :kv_function, opt.kind
    assert_equal "max", opt.name
    assert_equal "5", opt.arg
  end

  def test_number
    opt = SemanticCli::Option.new("123")
    assert_equal :parameter, opt.kind
    assert_equal "123", opt.arg
  end

  def test_word
    opt = SemanticCli::Option.new("log")
    assert_equal :word, opt.kind
    assert_equal "log", opt.name
  end
end
