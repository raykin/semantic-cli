module SemanticCli
  class Parser
    def initialize(argv, dsl)
      @tokens = argv.dup
      @dsl = dsl
      @fragments = []
    end

    def build_fragments
      i = 0
      last_fn = nil
      last_fn_consumed_arg = false

      while i < @tokens.size
        token = @tokens[i]
        next_token = @tokens[i + 1]
        fragment = parse_token(token, next_token, last_fn, last_fn_consumed_arg)

        if fragment
          @fragments << fragment
          last_fn = fragment.name
          last_fn_consumed_arg = fragment.arg ? true : false
          i += fragment.arg ? 2 : 1
        else
          i += 1
        end
      end

      @fragments
    end

    def parse_token(token, next_token, last_fn, last_fn_consumed_arg)
      opt = Option.new(token)

      case opt.kind
      when :kv_function
        return Fragment.new(opt.name, opt.arg, @dsl.call(opt.name, opt.arg)) if @dsl.exists?(opt.name)
        warn "Unknown function: #{opt.name}"
        return nil

      when :parameter
        if last_fn && @dsl.expects_arg?(last_fn) && !last_fn_consumed_arg
          return Fragment.new(last_fn, opt.arg, @dsl.call(last_fn, opt.arg))
        else
          warn "Orphan parameter: #{opt.arg}"
          return nil
        end

      when :word
        if @dsl.exists?(opt.name)
          if @dsl.expects_arg?(opt.name) && next_token && !@dsl.exists?(next_token) && !next_token.include?(":")
            return Fragment.new(opt.name, next_token, @dsl.call(opt.name, next_token))
          else
            return Fragment.new(opt.name, nil, @dsl.call(opt.name))
          end
        else
          if last_fn && @dsl.expects_arg?(last_fn) && !last_fn_consumed_arg
            return Fragment.new(last_fn, opt.name, @dsl.call(last_fn, opt.name))
          else
            warn "Unknown token: #{opt.name}"
            return nil
          end
        end
      end
    end
  end
end
