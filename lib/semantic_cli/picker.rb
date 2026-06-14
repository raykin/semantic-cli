module SemanticCli
  module Picker
    def self.dig_field(item, field)
      parts = field.to_s.split(".")
      parts.reduce(item) { |obj, key| obj.is_a?(Hash) ? (obj[key] || obj[key.to_sym]) : nil }
    end

    def self.display_value(item, field)
      dig_field(item, field).to_s
    end

    def self.print_info(items, display_fields:)
      headers = display_fields.map(&:to_s)
      rows = items.map { |item| display_fields.map { |f| display_value(item, f) } }

      widths = headers.each_with_index.map do |h, i|
        [h.length, *rows.map { |r| r[i].length }].max
      end

      header_line = headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join("  ")
      separator = widths.map { |w| "-" * w }.join("  ")

      puts header_line
      puts separator
      rows.each { |r| puts r.each_with_index.map { |c, i| c.ljust(widths[i]) }.join("  ") }
      puts
    end

    def self.select_item(items, display_fields:, id_field:)
      require "cli/ui"

      labels = items.map do |item|
        display_fields.map { |f| display_value(item, f) }.join(" | ")
      end

      puts "Ctrl+C to quit"
      chosen_label = CLI::UI::Prompt.ask("Select an item:", options: labels)
      index = labels.index(chosen_label)
      items[index]
    end

    def self.select_action(actions)
      require "cli/ui"
      CLI::UI::Prompt.ask("Choose an action:", options: actions.keys)
    end
  end
end
