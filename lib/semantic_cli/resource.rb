module SemanticCli
  class Resource
    attr_reader :name, :aliases, :identity_field, :display_fields, :actions

    def initialize(name, aliases: [])
      @name = name.to_s
      @aliases = aliases.map(&:to_s)
      @list_block = nil
      @identity_field = nil
      @display_fields = []
      @actions = {}
    end

    def list_command
      @list_block&.call
    end

    Action = Data.define(:name, :block) do
      def build_command(item)
        block.call(item)
      end
    end

    class Builder
      def initialize(resource)
        @resource = resource
      end

      def list(&block)
        @resource.instance_variable_set(:@list_block, block)
      end

      def id(field)
        @resource.instance_variable_set(:@identity_field, field)
      end

      def display(*fields)
        @resource.instance_variable_set(:@display_fields, fields)
      end

      def action(name, &block)
        @resource.actions[name.to_s] = Action.new(name: name.to_s, block: block)
      end
    end

    def self.build(name, aliases: [], &block)
      resource = new(name, aliases: aliases)
      Builder.new(resource).instance_eval(&block)
      resource
    end
  end
end
