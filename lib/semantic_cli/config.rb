module SemanticCli
  module Config
    FILENAME = ".axrc"

    def self.load(start_dir = Dir.pwd)
      path = find(start_dir)
      return {} unless path

      parse(File.read(path))
    end

    def self.find(start_dir)
      dir = File.expand_path(start_dir)
      loop do
        candidate = File.join(dir, FILENAME)
        return candidate if File.exist?(candidate)
        parent = File.dirname(dir)
        return nil if parent == dir
        dir = parent
      end
    end

    def self.parse(content)
      settings = {}
      content.each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        key, value = line.split("=", 2)
        settings[key.strip.to_sym] = value.strip if key && value
      end
      settings
    end
  end
end
