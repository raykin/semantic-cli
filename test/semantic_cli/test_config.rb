require "test_helper"
require "tmpdir"

class TestConfig < Minitest::Test
  def test_parse_key_value
    content = "profile=raykin-cli\nregion=ap-southeast-2\n"
    result = SemanticCli::Config.parse(content)
    assert_equal "raykin-cli", result[:profile]
    assert_equal "ap-southeast-2", result[:region]
  end

  def test_parse_ignores_comments_and_blanks
    content = "# this is a comment\n\nprofile=default\n"
    result = SemanticCli::Config.parse(content)
    assert_equal({ profile: "default" }, result)
  end

  def test_parse_handles_spaces_around_equals
    content = "profile = raykin-cli\n"
    result = SemanticCli::Config.parse(content)
    assert_equal "raykin-cli", result[:profile]
  end

  def test_find_in_current_dir
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".axrc"), "profile=test\n")
      assert_equal File.join(dir, ".axrc"), SemanticCli::Config.find(dir)
    end
  end

  def test_find_walks_up
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".axrc"), "profile=parent\n")
      child = File.join(dir, "subdir")
      Dir.mkdir(child)
      assert_equal File.join(dir, ".axrc"), SemanticCli::Config.find(child)
    end
  end

  def test_find_returns_nil_when_missing
    Dir.mktmpdir do |dir|
      assert_nil SemanticCli::Config.find(dir)
    end
  end

  def test_load_returns_settings
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".axrc"), "profile=raykin-cli\n")
      result = SemanticCli::Config.load(dir)
      assert_equal({ profile: "raykin-cli" }, result)
    end
  end

  def test_load_returns_empty_when_no_file
    Dir.mktmpdir do |dir|
      assert_equal({}, SemanticCli::Config.load(dir))
    end
  end
end
