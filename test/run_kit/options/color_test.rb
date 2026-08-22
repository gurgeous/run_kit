require "run_kit"

module RunKit
  module Options
    class ColorTest < Minitest::Test
      def test_basic
        # nil = auto
        $stdout.stubs(:tty?).returns(true)
        assert_equal "\e[1;34mtext\e[0m", Color.new(nil).blue("text")
        $stdout.stubs(:tty?).returns(false)
        assert_equal "text", Color.new(nil).blue("text")

        # bools
        assert_equal "\e[1;34mtext\e[0m", Color.new(true).blue("text")
        $stdout.stubs(:tty?).returns(true)
        assert_equal "text", Color.new(false).blue("text")
      end
    end
  end
end
