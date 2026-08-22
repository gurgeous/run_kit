require "run_kit"

module RunKit
  class TermTest < Minitest::Test
    def test_ansi8
      assert_equal [*0..7, 9], Term::ANSI8.values
      assert_equal 31, Term.ansi8_fg(:red)
      assert_equal 39, Term.ansi8_fg(:default)
      assert_equal 41, Term.ansi8_bg(:red)
      assert_equal 49, Term.ansi8_bg(:default)
    end

    def test_winsize
      IO.stubs(:console).returns(nil)
      assert_equal [48, 80], Term.winsize

      console = mock(winsize: [24, 120])
      IO.stubs(:console).returns(console)
      assert_equal [24, 120], Term.winsize
    end

    def test_with_hidden_cursor
      output = StringIO.new
      assert_equal :done, Term.with_hidden_cursor(output) { :done }
      assert_equal "\e[?25l\e[?25h", output.string

      output = StringIO.new
      assert_raises(RuntimeError) do
        Term.with_hidden_cursor(output) { raise "failed" }
      end
      assert_equal "\e[?25l\e[?25h", output.string
    end

    def test_width
      assert_equal 5, Term.width("plain")
      assert_equal 4, Term.width("\e[34mblue\e[0m")
    end

    def test_wrap
      blue = "\e[34mblue\e[0m"
      [
        ["", 10, ""],
        [" \t\r ", 10, ""],
        ["one two three", 7, "one two\nthree"],
        ["abcdefgh", 3, "abcdefgh"],
        ["  one\t two\n\nthree  ", 20, "one two\n\nthree"],
        ["#{blue} one two", 8, "#{blue} one\ntwo"],
        ["one\n", 20, "one\n"],
      ].each do |input, width, exp|
        assert_equal exp, Term.wrap(input, width), [input, width].inspect
      end
    end

    def test_paint
      assert_equal "\e[1;31mred\e[0m", Term.paint8("red", :red)
      assert_equal "\e[1;31mred\e[0m", Term.paint_ansi("red", "1", 31)
      assert_equal "\e[38;2;88;88;88mmuted\e[0m", Term.paint_muted("muted")
      assert_equal "\e[1;38;2;255;255;255;48;2;30;102;245mblue\e[0m", Term.paint_banner("blue", :blue)
    end

    def test_ansi
      assert_equal "38;2;210;15;57", Term.ansi_fg(:red)
      assert_equal "48;2;255;0;0", Term.ansi_bg([255, 0, 0])
    end

    def test_ansi256
      assert_equal "38;5;196", Term.ansi256_fg([255, 0, 0])
      assert_equal "48;5;161", Term.ansi256_bg(:red)

      colors = Term.ansi256_cube

      assert_equal 256, colors.length
      assert_equal [nil] * 16, colors.first(16)
      assert_equal [0, 0, 0], colors[16]
      assert_equal [255, 255, 255], colors[231]
      assert_equal [8, 8, 8], colors[232]
      assert_equal [238, 238, 238], colors[255]
    end

    def test_to_256
      assert_equal nil, Term.to_256(nil)
      assert_equal 9, Term.to_256(9)
      assert_equal 196, Term.to_256([255, 0, 0])
      assert_equal 46, Term.to_256("#00ff00")
      assert_equal 161, Term.to_256(:red)
    end

    def test_to_hex
      assert_equal nil, Term.to_hex(nil)
      assert_equal "#ff0000", Term.to_hex(196)
      assert_equal "#010203", Term.to_hex([1, 2, 3])
      assert_equal "#ABCDEF", Term.to_hex("#ABCDEF")
      assert_equal "#d20f39", Term.to_hex(:red)
      assert_equal "#010203", Term.rgb_to_hex([1, 2, 3])
    end

    def test_to_rgb
      assert_equal nil, Term.to_rgb(nil)
      assert_equal [255, 0, 0], Term.to_rgb(196)
      assert_equal [1, 2, 3], Term.to_rgb([1, 2, 3])
      assert_equal [171, 205, 239], Term.to_rgb("#ABCDEF")
      assert_equal [210, 15, 57], Term.to_rgb(:red)
      assert_equal [171, 205, 239], Term.hex_to_rgb("#ABCDEF")
    end
  end
end
