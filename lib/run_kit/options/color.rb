#
# A simple color toggle that can format text. If unset infer from stdout.tty.
#

module RunKit
  module Options
    class Color
      attr_reader :enabled
      alias_method :enabled?, :enabled

      def initialize(enabled)
        @enabled = enabled.nil? ? $stdout.tty? : enabled
      end

      # one-liners
      def blue(str) = paint8(str, :blue)
      def cyan(str) = paint8(str, :cyan)
      def green(str) = paint8(str, :green)
      def magenta(str) = paint8(str, :magenta)
      def red(str) = paint8(str, :red)
      def yellow(str) = paint8(str, :yellow)

      protected

      def paint8(str, ansi8)
        enabled? ? Term.paint8(str, ansi8) : str
      end
    end
  end
end
