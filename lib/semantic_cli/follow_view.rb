require "io/console"

module SemanticCli
  class FollowView
    MAX_LINES = 20_000
    FRAME_SECONDS = 1.0 / 30
    STOP_SECONDS = 0.5
    COMMAND_ENV = {"SYSTEMD_COLORS" => "1"}.freeze
    HINT = "  PgUp/PgDn scroll · End follow · q quit"

    class LineWrapper
      WIDE = [
        0x1100..0x115F, 0x2E80..0x303E, 0x3041..0x33FF, 0x3400..0x4DBF,
        0x4E00..0x9FFF, 0xA000..0xA4CF, 0xAC00..0xD7A3, 0xF900..0xFAFF,
        0xFE30..0xFE4F, 0xFF00..0xFF60, 0xFFE0..0xFFE6, 0x1F300..0x1F64F,
        0x1F900..0x1F9FF, 0x20000..0x3FFFD
      ].freeze
      ESCAPE = /\e[\]P^_X][^\a\e]*(?:\a|\e\\)|\e\[[0-?]*[ -\/]*[@-~]|\e[ -\/]*[0-~]/
      TOKEN = /#{ESCAPE}|\t|[ -~]+|\X/
      PLAIN = /\A[ -~]*\z/
      SGR = /\A\e\[[0-9;:]*m\z/
      RESET = /\A\e\[0*m\z/
      ZERO_WIDTH = /\A[\p{Mn}\p{Me}\p{Cc}\p{Cf}]/
      EMOJI = /\A\p{Emoji_Presentation}|\uFE0F/

      def initialize(width)
        @width = [width, 1].max
        @chunk = /.{1,#{@width}}/
      end

      def rows(line)
        return line.empty? ? [""] : line.scan(@chunk) if line.match?(PLAIN)

        @rows = []
        @row = +""
        @used = 0
        @styles = []
        line.scan(TOKEN) { |token| add_token(token) }
        @rows << @row
      end

      private

      def add_token(token)
        if token.start_with?("\e")
          add_escape(token)
        elsif token == "\t"
          add_tab
        elsif token.match?(PLAIN)
          add_plain(token)
        else
          add_char(token)
        end
      end

      def add_escape(token)
        return unless token.match?(SGR)

        token.match?(RESET) ? @styles.clear : @styles << token
        @row << token
      end

      def add_tab
        break_row if @used >= @width
        add_plain(" " * [8 - @used % 8, @width - @used].min)
      end

      def add_plain(text)
        until text.empty?
          break_row if @used >= @width
          room = @width - @used
          @row << text[0, room]
          @used += [text.size, room].min
          text = text[room..] || ""
        end
      end

      def add_char(char)
        return if char.match?(/\A\p{Cc}/)

        size = char_width(char)
        break_row if @used + size > @width && @used > 0
        @row << char
        @used += size
      end

      def break_row
        @rows << (@styles.empty? ? @row : @row + "\e[0m")
        @row = @styles.join
        @used = 0
      end

      def char_width(char)
        return 0 if char.match?(ZERO_WIDTH)
        return 2 if char.match?(EMOJI)

        code = char.ord
        (WIDE.any? { |range| range.cover?(code) }) ? 2 : 1
      end
    end

    class LineSplitter
      def initialize
        @partial = "".b
      end

      def feed(chunk)
        lines = (@partial + chunk.b).split("\n", -1)
        @partial = lines.pop
        lines.map { |line| decode(line) }
      end

      def flush
        return [] if @partial.empty?

        line = decode(@partial)
        @partial = "".b
        [line]
      end

      private

      def decode(bytes)
        bytes.force_encoding(Encoding::UTF_8).scrub.delete_suffix("\r")
      end
    end

    module Keys
      MAP = {
        "\e[5~" => :page_up, "\e[6~" => :page_down,
        "\e[A" => :up, "\eOA" => :up, "k" => :up,
        "\e[B" => :down, "\eOB" => :down, "j" => :down,
        "\e[H" => :home, "\eOH" => :home, "\e[1~" => :home, "\e[7~" => :home, "g" => :home,
        "\e[F" => :end, "\eOF" => :end, "\e[4~" => :end, "\e[8~" => :end, "G" => :end,
        "q" => :quit, "\x03" => :quit
      }.freeze
      PATTERN = Regexp.union(MAP.keys.sort_by { |key| -key.size })

      def self.parse(input)
        input.scan(PATTERN).map { |key| MAP[key] }
      end
    end

    class Screen
      attr_reader :width, :height, :exit_status

      def initialize(width:, height:, max_lines: MAX_LINES)
        @max_lines = max_lines
        @lines = []
        @scrolled_top = nil
        resize(width: width, height: height)
      end

      def resize(width:, height:)
        width = [width, 1].max
        @height = [height - 1, 1].max
        return if width == @width

        top_line = line_at(@scrolled_top) if @scrolled_top
        @width = width
        @wrapper = LineWrapper.new(@width)
        @counts = []
        @rows = []
        @lines.each { |line| add_rows(line) }
        @scrolled_top = @counts.first(top_line).sum if top_line
      end

      def append(lines)
        @lines.concat(lines)
        lines.each { |line| add_rows(line) }
        trim
      end

      def finish(exit_status)
        @exit_status = exit_status
      end

      def following?
        @scrolled_top.nil?
      end

      def total
        @rows.size
      end

      def start
        following? ? bottom : [@scrolled_top, bottom].min
      end

      def visible
        @rows[start, @height] || []
      end

      def press(key)
        case key
        when :page_up then scroll_to(start - @height)
        when :page_down then scroll_to(start + @height)
        when :up then scroll_to(start - 1)
        when :down then scroll_to(start + 1)
        when :home then scroll_to(0)
        when :end then @scrolled_top = nil
        end
      end

      def status
        mode = following? ? "\e[32m[TAIL]\e[0m" : "\e[33m[SCROLL] #{start + @height}/#{total}\e[0m"
        mode += " \e[31m[EXITED #{exit_status}]\e[0m" if exit_status
        @wrapper.rows("#{mode}\e[2m#{HINT}\e[0m").first
      end

      private

      def bottom
        [total - @height, 0].max
      end

      def scroll_to(row)
        row = [row, 0].max
        @scrolled_top = (row >= bottom) ? nil : row
      end

      def line_at(row)
        @counts.each_with_index do |count, index|
          return index if row < count
          row -= count
        end
        @counts.size
      end

      def add_rows(line)
        rows = @wrapper.rows(line)
        @counts << rows.size
        @rows.concat(rows)
      end

      def trim
        extra = @lines.size - @max_lines
        return if extra <= 0

        @lines.shift(extra)
        dropped = @counts.shift(extra).sum
        @rows.shift(dropped)
        @scrolled_top = [@scrolled_top - dropped, 0].max if @scrolled_top
      end
    end

    def self.available?
      $stdin.tty? && $stdout.tty?
    end

    def initialize(command, input: $stdin, output: $stdout)
      @command = command
      @input = input
      @output = output
      @splitter = LineSplitter.new
      @dirty = true
      @drawn_at = 0
    end

    def run
      rows, cols = @output.winsize
      @screen = Screen.new(width: cols, height: rows)
      @wake_reader, @wake_writer = IO.pipe
      previous_winch = trap("WINCH") { @wake_writer.write_nonblock(".", exception: false) }
      @pipe = IO.popen(COMMAND_ENV, popen_command, in: File::NULL, err: [:child, :out], pgroup: true)
      @output.write("\e[?1049h\e[?25l\e[?7l")
      @input.raw { follow_until_quit }
    ensure
      stop_command
      @output.write("\e[0m\e[?7h\e[?25h\e[?1049l")
      trap("WINCH", previous_winch || "DEFAULT")
      [@wake_reader, @wake_writer].compact.each(&:close)
    end

    private

    def popen_command
      stdbuf = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
        .map { |dir| File.join(dir, "stdbuf") }
        .find { |path| File.executable?(path) }
      stdbuf ? [stdbuf, "-oL", "sh", "-c", @command] : @command
    end

    def follow_until_quit
      until @quit
        readers = [@input, @wake_reader]
        readers << @pipe unless @pipe.closed?
        ready, = IO.select(readers, nil, nil, @dirty ? redraw_wait : nil)

        (ready || []).each do |io|
          case io
          when @pipe then read_command
          when @wake_reader then resize
          when @input then read_keys
          end
        end

        draw if @dirty && redraw_wait.zero?
      end
    end

    def redraw_wait
      [@drawn_at + FRAME_SECONDS - now, 0].max
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def read_command
      chunk = @pipe.read_nonblock(64 * 1024, exception: false)
      return if chunk == :wait_readable

      chunk.nil? ? finish_command : @screen.append(@splitter.feed(chunk))
      @dirty = true
    end

    def finish_command
      @screen.append(@splitter.flush)
      @pipe.close
      @screen.finish($?.exitstatus || $?.termsig)
    end

    def read_keys
      input = @input.read_nonblock(1024, exception: false)
      return if input == :wait_readable

      keys = input.nil? ? [:quit] : Keys.parse(input)
      @quit = keys.include?(:quit)
      keys.each { |key| @screen.press(key) } unless @quit
      @dirty = true
    end

    def resize
      @wake_reader.read_nonblock(1024, exception: false)
      rows, cols = @output.winsize
      @screen.resize(width: cols, height: rows)
      @dirty = true
    end

    def draw
      frame = +""
      visible = @screen.visible
      @screen.height.times { |i| frame << "\e[#{i + 1};1H\e[2K#{visible[i]}\e[0m" }
      frame << "\e[#{@screen.height + 1};1H\e[2K#{@screen.status}\e[0m"
      @output.write(frame)
      @output.flush
      @drawn_at = now
      @dirty = false
    end

    def stop_command
      return if @pipe.nil? || @pipe.closed?

      signal_group("TERM")
      deadline = now + STOP_SECONDS
      sleep 0.02 while group_alive? && now < deadline
      signal_group("KILL")
      @pipe.close
    end

    def signal_group(signal)
      Process.kill(signal, -@pipe.pid)
    rescue Errno::ESRCH
    end

    def group_alive?
      reap_shell
      Process.kill(0, -@pipe.pid)
      true
    rescue Errno::ESRCH
      false
    end

    def reap_shell
      @shell_reaped ||= Process.wait(@pipe.pid, Process::WNOHANG)
    rescue Errno::ECHILD
      @shell_reaped = true
    end
  end
end
