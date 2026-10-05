module SemanticCli
  class Runner
    PROMPTS = /\bsudo\b/
    def initialize(dsl, picker: Picker, viewer: FollowView)
      @dsl = dsl
      @picker = picker
      @viewer = viewer
    end

    def execute(argv)
      if argv.first == "__complete"
        puts @dsl.names
        return
      end

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

      resource_frags, cmd_frags = fragments.partition { |f| f.is_a?(ResourceFragment) }

      if resource_frags.any?
        execute_resource(resource_frags.first)
        return
      end

      command = cmd_frags.map(&:shell).compact.join(" | ")
      if command.empty?
        warn "No command built."
        return
      end

      command = "#{@dsl.env_prefix}#{command}"
      puts "→ Running: #{command}"
      if cmd_frags.any? { |f| @dsl.follow?(f.name) } && !command.match?(PROMPTS) && @viewer.available?
        @viewer.new(command).run
      else
        system command
      end
    end

    private

    def print_context(resource_name)
      profile = @dsl.get(:profile) || ENV["AWS_PROFILE"] || "default"
      region = @dsl.get(:region) || ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"]
      parts = ["profile: #{profile}"]
      parts << (region ? "region: #{region}" : "all regions")
      puts "Loading #{resource_name} (#{parts.join(", ")})..."
    end

    def debug(msg)
      warn "[debug] #{msg}" if @dsl.debug?
    end

    def execute_resource(fragment)
      resource = fragment.resource
      prefix = @dsl.env_prefix
      list_cmd = "#{prefix}#{resource.list_command}"

      print_context(resource.name)
      debug "list_cmd: #{list_cmd}"

      json_output = `#{list_cmd}`
      debug "response: #{json_output.strip.slice(0, 500)}"

      unless $?.success?
        warn "Command failed (exit #{$?.exitstatus})."
        return
      end

      items = JSON.parse(json_output)
      items = items.values.first if items.is_a?(Hash)

      if items.empty?
        warn "No items found."
        return
      end

      @picker.print_info(items, display_fields: resource.display_fields)
      selected = @picker.select_item(items, display_fields: resource.display_fields, id_field: resource.identity_field)

      if fragment.action_name
        action = resource.actions[fragment.action_name]
        command = action.build_command(selected)
      else
        action_name = @picker.select_action(resource.actions)
        action = resource.actions[action_name]
        command = action.build_command(selected)
      end

      command = "#{prefix}#{command}"
      puts "→ Running: #{command}"
      system command
    rescue Interrupt
      puts
    end
  end
end
