module SemanticCli
  class Runner
    def initialize(dsl)
      @dsl = dsl
    end

    def execute(argv)
      if argv.empty?
        if @dsl.exists?('')
          help_text = @dsl.call('')
          puts help_text unless help_text.to_s.strip.empty?
        else
          warn "No command given."
        end
        return
      end

      parser = Parser.new(argv, @dsl)
      fragments = parser.build_fragments

      command = fragments.map(&:shell).compact.join(" | ")
      if command.empty?
        warn "No command built."
        return
      end

      puts "→ Running: #{command}"
      system command
    end
  end
end
