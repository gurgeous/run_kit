# ANSI-aware terminal helpers.
module RunKit
  module Term
    module_function

    #
    # terminal helpers
    #

    # Calculate terminal width, defaulting to 48x80.
    def winsize(...)
      IO.console&.winsize(...) || [48, 80]
    end

    def with_hidden_cursor(output)
      output.write CURSOR_HIDE
      yield
    ensure
      output.write CURSOR_SHOW
    end

    # Measure characters while ignoring ANSI control sequences.
    def width(str) = str.gsub(ANSI_RE, "").length

    # Return word-wrapped text. ANSI escapes are taked into account, but we do
    # not wrap colored regions across lines.
    def wrap(str, truncate_to)
      return "" if str.empty?

      lines, words = [], []
      tokens = str.split(/[ \t\r]+|(\n)/).reject(&:empty?) # words and newlines
      tokens.each do |word|
        if word == "\n"
          lines << words.join(" ")
          words = []
          next
        end
        if !words.empty? && width("#{words.join(" ")} #{word}") > truncate_to
          lines << words.join(" ")
          words = []
        end

        words << word
      end
      lines << words.join(" ") unless words.empty?
      lines << "" if tokens.last == "\n"
      lines.join("\n")
    end

    #
    # painting color strings
    #

    PALETTE = {
      # catppuccin latte
      rosewater: "#dc8a78",
      flamingo: "#dd7878",
      pink: "#ea76cb",
      mauve: "#8839ef",
      red: "#d20f39",
      maroon: "#e64553",
      peach: "#fe640b",
      yellow: "#df8e1d",
      green: "#40a02b",
      teal: "#179299",
      sky: "#04a5e5",
      sapphire: "#209fb5",
      blue: "#1e66f5",
      lavender: "#7287fd",
      text: "#4c4f69",
      subtext1: "#5c5f77",
      subtext0: "#6c6f85",
      overlay2: "#7c7f93",
      overlay1: "#8c8fa1",
      overlay0: "#9ca0b0",
      surface2: "#acb0be",
      surface1: "#bcc0cc",
      surface0: "#ccd0da",
      base: "#eff1f5",
      mantle: "#e6e9ef",
      crust: "#dce0e8",

      # some basic colors
      white: "#ffffff",
      black: "#000000",
      muted: "#585858",
    }

    def paint8(str, color) = paint_ansi(str, BOLD, ansi8_fg(color))
    def paint_ansi(str, *codes) = "#{CSI}#{codes.join(";")}m#{str}#{RESET}"
    def paint_muted(str) = paint_ansi(str, ansi_fg(:muted))
    def paint_banner(str, color) = paint_ansi(str, BOLD, ansi_fg(:white), ansi_bg(color))

    #
    # ANSI escape codes and colors. ANSI itself supports three different colors
    # schemes (8-color table, 256 indexed color cube, and full rgb). We have
    # helpers for each.
    #

    ANSI_RE = /\e\[[\d;]*m/
    ESC = "\e"
    CSI = "#{ESC}["
    BOLD = "1"
    RESET = "#{CSI}0m"
    CURSOR_HIDE = "#{CSI}?25l"
    CURSOR_SHOW = "#{CSI}?25h"

    #
    # ansi rgb / direct / 24m color formatting. This is the easiest to use and
    # almost always the right choice.
    #

    def ansi_fg(color) = "38;2;#{to_rgb(color).join(";")}"
    def ansi_bg(color) = "48;2;#{to_rgb(color).join(";")}"

    #
    # ANSI 8-color table, map from color symbol to color index. Use this if you
    # want to paint in the user's own terminal color palette. Not good for
    # reverse color or fine control.
    #

    ANSI8 = {black: 0, red: 1, green: 2, yellow: 3, blue: 4, magenta: 5, cyan: 6, white: 7, default: 9}

    def ansi8_fg(name8) = 30 + ANSI8.fetch(name8)
    def ansi8_bg(name8) = 40 + ANSI8.fetch(name8)

    #
    # ANSI 256 indexed color cube. Rarely used. If you want to use ansi 256 for
    # compat or perf reasons, choose your color palette in advance instead of
    # converting on the fly with this stuff.
    #

    def ansi256_fg(color) = "38;5;#{to_256(color)}"
    def ansi256_bg(color) = "48;5;#{to_256(color)}"

    def ansi256_cube
      @ansi256_cube ||= begin
        cube = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]
        rgb_for = ->(idx) do
          if idx >= 232
            r = g = b = 8 + (idx - 232) * 10
          else
            off = idx - 16
            r = cube[(off / 36) % 6]
            g = cube[(off / 6) % 6]
            b = cube[(off / 1) % 6]
          end
          [r, g, b]
        end
        Array.new(256) { rgb_for.call(_1) if _1 >= 16 }
      end
    end

    #
    # color converters. `color` is any of:
    # - nil
    # - an ansi 256 color cube index
    # - an [r,g,b] channel array
    # - a hex color string "#rrggbb"
    # - one of our named PALETTE symbols
    #

    HEX_RE = /\A#[\da-f]{6}\z/i

    def to_256(color)
      case color
      when nil then return
      when (0..255) then return color
      end
      rgb = to_rgb(color)
      (16..255).min_by do |idx|
        rgb.zip(ansi256_cube[idx]).sum { |a, b| (a - b)**2 }
      end
    end

    def to_hex(color)
      case color
      when nil then color
      when (16..255) then rgb_to_hex(ansi256_cube[color])
      when Array then rgb_to_hex(color)
      when HEX_RE then color
      when Symbol then PALETTE.fetch(color)
      else; raise "unknown color format #{color.inspect}"
      end
    end

    def to_rgb(color)
      case color
      when nil then color
      when (16..255) then ansi256_cube[color]
      when Array then color
      when HEX_RE then hex_to_rgb(color)
      when Symbol then hex_to_rgb(PALETTE.fetch(color))
      else; raise "unknown color format #{color.inspect}"
      end
    end

    def hex_to_rgb(hex) = hex.delete_prefix("#").scan(/../).map { _1.to_i(16) }
    def rgb_to_hex(rgb) = sprintf("#%02x%02x%02x", *rgb)
  end
end
