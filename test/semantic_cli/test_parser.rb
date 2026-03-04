require "test_helper"

class TestParser < Minitest::Test
  def setup
    @dsl = SemanticCli::DSL.new

    # Core functions
    @dsl.define("log")       { |svc| "journalctl -u #{svc} -f" }   # arity 1
    @dsl.define("port")      { |num| "lsof -i :#{num}" }            # arity 1
    @dsl.define("dirsize")   { "du -sh -- * | sort -hr" }           # arity 0
    @dsl.define("max")       { |n| "head -n#{n}" }                  # arity 1
    @dsl.define("min")       { |n| "tail -n#{n}" }                  # arity 1
    @dsl.define("grep")      { |term| "grep #{term}" }              # arity 1
    @dsl.define("http") do |site = "google"|
      site += ".com" unless site.include?(".")
      "sudo tcpdump -n -i any tcp and ip and greater 90 and src #{site}"
    end
  end

  def parse(argv)
    SemanticCli::Parser.new(argv, @dsl).build_fragments
  end

  def shells(argv)
    parse(argv).map(&:shell)
  end

  # --- key:value function calls ---

  def test_kv_function_is_resolved_directly
    assert_equal ["head -n5"], shells(%w[max:5])
    assert_equal ["tail -n10"], shells(%w[min:10])
  end

  def test_kv_function_unknown_emits_warning
    _, err = capture_io { shells(%w[unknown:5]) }
    assert_match(/Unknown function: unknown/, err)
    assert_equal [], shells(%w[unknown:5])
  end

  # --- arity-1 functions consuming next token ---

  def test_word_plus_parameter_consumes_next_for_arity_one
    assert_equal ["journalctl -u v2ray -f"], shells(%w[log v2ray])
    assert_equal ["lsof -i :8888"], shells(%w[port 8888])
  end

  def test_word_with_unknown_next_token_treated_as_param
    # next token is not a known function and not key:value → treated as param
    assert_equal ["journalctl -u elastic -f"], shells(%w[log elastic])
  end

  # --- numbers as parameters ---

  def test_number_is_parameter_and_attaches_to_last_fn_needing_arg
    assert_equal ["head -n3"], shells(%w[max 3])
  end

  def test_orphan_number_emits_warning
    _, err = capture_io { shells(%w[123]) }
    assert_match(/Orphan parameter: 123/, err)
    assert_equal [], shells(%w[123])
  end

  # --- unknown word as parameter to previous function ---

  def test_unknown_word_attaches_as_param_if_previous_fn_needs_arg
    # 'zzz' is unknown, but 'log' needs an arg → attach as param
    assert_equal ["journalctl -u zzz -f"], shells(%w[log zzz])
  end

  def test_unknown_word_without_previous_needing_arg_warns
    _, err = capture_io { shells(%w[unknown]) }
    assert_match(/Unknown token: unknown/, err)
    assert_equal [], shells(%w[unknown])
  end

  # --- arity-0 functions ---

  def test_arity_zero_function_emits_shell_without_param
    assert_equal ["du -sh -- * | sort -hr"], shells(%w[dirsize])
  end

  def test_arity_zero_function_followed_by_number_does_not_consume
    # dirsize doesn't need an arg; 5 becomes orphan
    _, err = capture_io { shells(%w[dirsize 5]) }
    assert_match(/Orphan parameter: 5/, err)
    assert_equal ["du -sh -- * | sort -hr"], shells(%w[dirsize 5])
  end

  # --- mixed sequences and chaining ---

  def test_chain_dirsize_with_max_via_kv_and_word_param
    assert_equal(
      ["du -sh -- * | sort -hr", "head -n3"],
      shells(%w[dirsize max:3])
    )
    assert_equal(
      ["du -sh -- * | sort -hr", "head -n3"],
      shells(%w[dirsize max 3])
    )
  end

  def test_chain_log_with_grep_and_term
    assert_equal(
      ["journalctl -u v2ray -f", "grep error"],
      shells(%w[log v2ray grep error])
    )
  end

  def test_multiple_fragments_join_order_is_preserved
    assert_equal(
      ["lsof -i :8888", "grep node"],
      shells(%w[port 8888 grep node])
    )
  end

  # --- ambiguous next-token handling ---

  def test_next_token_is_known_function_not_consumed_as_param
    # After 'log', next token is 'grep' which is a known function → do not consume
    frags = parse(%w[log grep error])
    assert_equal "journalctl -u  -f", frags[0].shell # log called without arg
    assert_equal "grep error", frags[1].shell
  end

  def test_next_token_is_kv_not_consumed_as_param
    # 'max:5' is kv → not a param to 'log'
    frags = parse(%w[log max:5])
    assert_equal "journalctl -u  -f", frags[0].shell
    assert_equal "head -n5", frags[1].shell
  end

  # --- edge: missing parameter for arity-1 function ---

  def test_missing_param_for_arity_one_calls_without_arg_transparently
    # Log expects an arg; none provided → called with nil
    frags = parse(%w[log])
    assert_equal "journalctl -u  -f", frags.first.shell
  end

  # --- help behavior is Runner, but validate fragments neutral state ---

  def test_parser_with_empty_argv_returns_no_fragments
    assert_equal [], parse([])
  end

  def test_http_with_default
    frags = parse(%w[http])
    assert_equal "sudo tcpdump -n -i any tcp and ip and greater 90 and src google.com", frags.first.shell
  end

  def test_http_with_arg_word
    frags = parse(%w[http ollama])
    assert_equal "sudo tcpdump -n -i any tcp and ip and greater 90 and src ollama.com", frags.first.shell
  end

  def test_http_with_arg_kv
    frags = parse(%w[http:ollama])
    assert_equal "sudo tcpdump -n -i any tcp and ip and greater 90 and src ollama.com", frags.first.shell
  end

  # --- rest args ---

  def test_rest_args_consumes_remaining_tokens
    @dsl.define("dns") { |c1, *rest| "networksetup -setdnsservers wifi #{c1} #{rest.join(" ")}" }
    assert_equal ["networksetup -setdnsservers wifi set 8.8.8.8 8.8.4.4"], shells(%w[dns set 8.8.8.8 8.8.4.4])
  end

  def test_rest_args_with_single_arg
    @dsl.define("dns") { |c1, *rest| "networksetup -setdnsservers wifi #{c1} #{rest.join(" ")}" }
    assert_equal ["networksetup -setdnsservers wifi display "], shells(%w[dns display])
  end

  def test_rest_args_stops_at_known_function
    @dsl.define("dns") { |c1, *rest| "dns #{c1} #{rest.join(" ")}" }
    frags = parse(%w[dns set 8.8.8.8 dirsize])
    assert_equal 2, frags.size
    assert_equal "dns set 8.8.8.8", frags[0].shell
    assert_equal "du -sh -- * | sort -hr", frags[1].shell
  end
end
