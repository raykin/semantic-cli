module SemanticCli
  class Option
    attr_reader :raw, :kind, :name, :arg

    def initialize(raw)
      @raw = raw
      classify
    end

    def number?(s)
      s =~ /^\d+$/
    end

    def classify
      if raw.include?(":")
        key, val = raw.split(":", 2)
        @kind, @name, @arg = :kv_function, key, val
      elsif number?(raw)
        @kind, @name, @arg = :parameter, nil, raw
      else
        @kind, @name, @arg = :word, raw, nil
      end
    end
  end
end
