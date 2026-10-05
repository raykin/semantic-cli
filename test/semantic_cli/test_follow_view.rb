require "test_helper"

class TestFollowView < Minitest::Test
  def wrap(line, width)
    SemanticCli::FollowView::LineWrapper.new(width).rows(line)
  end

  def screen(width: 80, height: 4, max_lines: 100)
    SemanticCli::FollowView::Screen.new(width: width, height: height, max_lines: max_lines)
  end

  def test_wrap_splits_plain_text_at_width
    assert_equal %w[abcd efgh ij], wrap("abcdefghij", 4)
  end

  def test_wrap_keeps_empty_line
    assert_equal [""], wrap("", 4)
  end

  def test_wrap_ignores_escape_codes_when_counting_width
    assert_equal ["\e[31mabcd\e[0m"], wrap("\e[31mabcd\e[0m", 4)
  end

  def test_wrap_carries_color_to_next_row
    assert_equal ["\e[31mabcd\e[0m", "\e[31mef\e[0m"], wrap("\e[31mabcdef\e[0m", 4)
  end

  def test_wrap_does_not_carry_color_after_reset
    assert_equal ["\e[1mab\e[0mcd", "ef"], wrap("\e[1mab\e[0mcdef", 4)
  end

  def test_wrap_drops_non_color_escape_codes
    assert_equal ["ab"], wrap("a\e[2Kb\e[1G", 4)
  end

  def test_wrap_counts_wide_chars_as_two_columns
    assert_equal ["中文", "字"], wrap("中文字", 4)
    assert_equal ["a", "中"], wrap("a中", 2)
  end

  def test_wrap_expands_tabs
    assert_equal ["a       b"], wrap("a\tb", 20)
  end

  def test_wrap_counts_emoji_as_two_columns
    %w[🚀 ✅ 🇯🇵 🩷 ❤️].each { |emoji| assert_equal ["ab", emoji], wrap("ab#{emoji}", 3), emoji }
  end

  def test_wrap_tab_at_edge_starts_new_row_at_tab_stop
    assert_equal ["abcdefghij", "        X"], wrap("abcdefghij\tX", 10)
  end

  def test_wrap_tab_stops_at_row_end
    assert_equal ["abcdefgh  ", "X"], wrap("abcdefgh\tX", 10)
  end

  def test_wrap_drops_osc_charset_and_keeps_colon_colors
    assert_equal ["link"], wrap("\e]8;;http://x.test\e\\link\e]8;;\a", 10)
    assert_equal ["ab"], wrap("a\e(Bb", 10)
    assert_equal ["\e[38:5:1mab"], wrap("\e[38:5:1mab", 10)
  end

  def test_wrap_is_fast_for_long_buffers
    wrapper = SemanticCli::FollowView::LineWrapper.new(100)
    plain = "line " + "x" * 120
    colored = "\e[32mline\e[0m " + "x" * 120
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    10_000.times { wrapper.rows(plain) && wrapper.rows(colored) }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
  end

  def test_line_splitter_keeps_chars_split_across_reads
    splitter = SemanticCli::FollowView::LineSplitter.new
    bytes = "中文\nab\r\nc".b
    assert_equal [], splitter.feed(bytes[0, 2])
    assert_equal ["中文", "ab"], splitter.feed(bytes[2..])
    assert_equal ["c"], splitter.flush
    assert_equal [], splitter.flush
  end

  def test_line_splitter_scrubs_invalid_bytes
    splitter = SemanticCli::FollowView::LineSplitter.new
    assert_equal ["a\uFFFDb"], splitter.feed("a\xFFb\n".b)
  end

  def test_keys_parse_escape_sequences_and_letters
    keys = SemanticCli::FollowView::Keys.parse("\e[5~\e[6~\e[Ajk\e[FgGq\x03")
    assert_equal %i[page_up page_down up down up end home end quit quit], keys
  end

  def test_screen_starts_following_and_shows_last_rows
    s = screen
    s.append(%w[1 2 3 4 5])
    assert s.following?
    assert_equal %w[3 4 5], s.visible
  end

  def test_page_up_from_tail_switches_to_scroll
    s = screen
    s.append(%w[1 2 3 4 5 6 7])
    s.press(:page_up)
    refute s.following?
    assert_equal %w[2 3 4], s.visible
    assert_match(/\[SCROLL\] 4\/7/, s.status)
  end

  def test_scroll_view_stays_still_while_lines_arrive
    s = screen
    s.append(%w[1 2 3 4 5 6 7])
    s.press(:up)
    s.append(%w[8 9])
    assert_equal %w[4 5 6], s.visible
  end

  def test_page_up_stays_tail_when_lines_fit_screen
    s = screen
    s.append(%w[1 2])
    s.press(:page_up)
    assert s.following?
  end

  def test_end_resumes_tail
    s = screen
    s.append(%w[1 2 3 4 5 6 7])
    s.press(:home)
    assert_equal %w[1 2 3], s.visible
    s.press(:end)
    s.append(%w[8])
    assert s.following?
    assert_equal %w[6 7 8], s.visible
    assert_match(/\[TAIL\]/, s.status)
  end

  def test_page_down_to_bottom_resumes_tail
    s = screen
    s.append(%w[1 2 3 4 5 6 7])
    s.press(:page_up)
    s.press(:page_down)
    assert s.following?
  end

  def test_keeps_only_max_lines_and_scroll_view_stays_still
    s = screen(max_lines: 5)
    s.append(%w[1 2 3 4 5])
    s.press(:up)
    assert_equal %w[2 3 4], s.visible
    s.append(%w[6 7])
    assert_equal 5, s.total
    assert_equal %w[3 4 5], s.visible
  end

  def test_resize_rewraps_rows
    s = screen(width: 10)
    s.append(["abcdefghijkl"])
    assert_equal %w[abcdefghij kl], s.visible
    s.resize(width: 6, height: 4)
    assert_equal %w[abcdef ghijkl], s.visible
  end

  def test_resize_keeps_scrolled_line_at_top
    s = screen(width: 10)
    s.append((1..20).map { |i| "line#{i}" })
    s.press(:page_up)
    top = s.visible.first
    s.resize(width: 5, height: 4)
    refute s.following?
    assert_equal top[0, 5], s.visible.first
  end

  def test_status_shows_exit_status
    s = screen
    s.finish(1)
    assert_match(/\[EXITED 1\]/, s.status)
  end

  def test_status_fits_screen_width
    s = screen(width: 10)
    assert_equal "[TAIL]  Pg", s.status.gsub(/\e\[[0-9;]*m/, "")
  end
end
