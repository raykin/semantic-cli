module SemanticCli
  class Parser
    ParseResult = Data.define(:fragment, :consumed)

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
        result = parse_token(i, last_fn, last_fn_consumed_arg)

        if result
          @fragments << result.fragment
          last_fn = result.fragment.name
          last_fn_consumed_arg = result.consumed > 1
          i += result.consumed
        else
          i += 1
        end
      end

      @fragments
    end

    private

    def parse_token(index, last_fn, last_fn_consumed_arg)
      token = @tokens[index]
      next_token = @tokens[index + 1]
      opt = Option.new(token)

      case opt.kind
      when :kv_function
        return result(opt.name, opt.arg, 1) if @dsl.exists?(opt.name)
        warn "Unknown function: #{opt.name}"
        nil

      when :parameter
        if last_fn && @dsl.expects_arg?(last_fn) && !last_fn_consumed_arg
          result(last_fn, opt.arg, 1)
        else
          warn "Orphan parameter: #{opt.arg}"
          nil
        end

      when :word
        if @dsl.exists?(opt.name)
          if @dsl.expects_arg?(opt.name) && next_token && !@dsl.exists?(next_token) && !next_token.include?(":")
            if @dsl.expects_rest?(opt.name)
              rest_args = collect_rest(index + 1)
              result_rest(opt.name, rest_args, 1 + rest_args.size)
            else
              result(opt.name, next_token, 2)
            end
          else
            result(opt.name, nil, 1)
          end
        elsif last_fn && @dsl.expects_arg?(last_fn) && !last_fn_consumed_arg
          result(last_fn, opt.name, 1)
        else
          warn "Unknown token: #{opt.name}"
          nil
        end
      end
    end

    def collect_rest(start)
      args = []
      i = start
      while i < @tokens.size
        t = @tokens[i]
        break if @dsl.exists?(t) || t.include?(":")
        args << t
        i += 1
      end
      args
    end

    def result(name, arg, consumed)
      ParseResult.new(Fragment.new(name, arg, @dsl.call(name, arg)), consumed)
    end

    def result_rest(name, args, consumed)
      ParseResult.new(Fragment.new(name, args.first, @dsl.call(name, *args)), consumed)
    end
  end
end
