module SemanticCli
  class DSL
    class Function
      def initialize(block)
        @block = block
        @params = block.parameters
      end

      def expects_arg?
        @params.any? { |kind, _| kind == :req || kind == :opt }
      end

      def expects_rest?
        @params.any? { |kind, _| kind == :rest }
      end

      def call(*args)
        args = args.compact
        if expects_rest?
          @block.call(*args)
        elsif @params.any? { |kind, _| kind == :req }
          @block.call(args.first)
        elsif @params.any? { |kind, _| kind == :opt }
          args.empty? ? @block.call : @block.call(args.first)
        else
          @block.call
        end
      end
    end

    def initialize
      @functions = {}
    end

    def define(name, &block)
      name = name.to_s.strip
      if name != "" && name.split.size != 1
        raise ArgumentError, "Function name must be single word or empty string"
      end
      @functions[name] = Function.new(block)
    end

    def exists?(name)
      @functions.key?(name)
    end

    def expects_arg?(name)
      fn = @functions[name]
      return false unless fn
      fn.expects_arg?
    end

    def expects_rest?(name)
      fn = @functions[name]
      return false unless fn
      fn.expects_rest?
    end

    def call(name, *args)
      fn = @functions[name]
      return unless fn
      fn.call(*args)
    end
  end
end
