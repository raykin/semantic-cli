module SemanticCli
  class DSL
    def initialize
      @functions = {}
    end

    def define(name, &block)
      name = name.to_s.strip
      if name != '' && name.split.size != 1
        raise ArgumentError, "Function name must be single word or empty string"
      end
      @functions[name] = block
    end

    def exists?(name)
      @functions.key?(name)
    end

    def expects_arg?(name)
      blk = @functions[name]
      blk && blk.arity == 1
    end

    def call(name, arg = nil)
      blk = @functions[name]
      return nil unless blk
      blk.arity == 1 ? blk.call(arg) : blk.call
    end
  end
end
