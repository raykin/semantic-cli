require "test_helper"

class TestPicker < Minitest::Test
  def test_select_item_builds_labels_from_string_keys
    items = [
      {"instanceName" => "web-1", "state" => "running", "blueprintId" => "ubuntu_22"},
      {"instanceName" => "db-1", "state" => "stopped", "blueprintId" => "ubuntu_22"}
    ]

    labels = items.map do |item|
      [:instanceName, :state].map { |f| item[f.to_s] || item[f] }.join(" | ")
    end

    assert_equal "web-1 | running", labels[0]
    assert_equal "db-1 | stopped", labels[1]
  end

  def test_select_item_builds_labels_from_symbol_keys
    items = [
      {instanceName: "web-1", state: "running"},
      {instanceName: "db-1", state: "stopped"}
    ]

    labels = items.map do |item|
      [:instanceName, :state].map { |f| item[f.to_s] || item[f] }.join(" | ")
    end

    assert_equal "web-1 | running", labels[0]
    assert_equal "db-1 | stopped", labels[1]
  end

  def test_dig_field_flat
    item = {"name" => "web-1", "blueprintId" => "ubuntu_24"}
    assert_equal "web-1", SemanticCli::Picker.dig_field(item, :name)
    assert_equal "ubuntu_24", SemanticCli::Picker.dig_field(item, :blueprintId)
  end

  def test_dig_field_nested
    item = {"state" => {"code" => 16, "name" => "running"}}
    assert_equal "running", SemanticCli::Picker.dig_field(item, :"state.name")
    assert_equal 16, SemanticCli::Picker.dig_field(item, :"state.code")
  end

  def test_dig_field_missing
    item = {"name" => "web-1"}
    assert_nil SemanticCli::Picker.dig_field(item, :"state.name")
  end

  def test_print_info_outputs_table
    items = [
      {"name" => "web-1", "state" => {"name" => "running"}, "publicIpAddress" => "203.0.113.1"},
      {"name" => "db-1", "state" => {"name" => "stopped"}, "publicIpAddress" => "203.0.113.2"}
    ]

    out, _ = capture_io do
      SemanticCli::Picker.print_info(items, display_fields: [:name, :"state.name", :publicIpAddress])
    end

    assert_match(/name/, out)
    assert_match(/state\.name/, out)
    assert_match(/web-1/, out)
    assert_match(/running/, out)
    assert_match(/203\.0\.113\.1/, out)
  end
end
