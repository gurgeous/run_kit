#
# Renders the generated help text. Most of the fiddly work here is keeping
# columns aligned while ANSI color is present.
#

module RunKit
  module Options
    class Help
      INDENT = 2

      attr_reader :config, :width

      def initialize(config, width = nil)
        @config = config
        @width = (width || Term.winsize[1]).clamp(60, 100)
      end

      # Render generated help, unless the caller supplied complete help text.
      def to_s
        return config.help if config.help

        # usage: xyz (banner)
        buf = StringIO.new
        buf << banner
        buf << "\n"
        buf << "\n" if config.separators.any? { _1.first.zero? }

        # Render each flag with aligned switch labels and wrapped help text.
        label_width = widest_label
        config.flags.each.with_index do |flag, idx|
          buf << separator_text(idx) # sep

          # left
          label = flag_label(flag)
          buf << " " * INDENT
          buf << label

          # right
          if flag.help
            buf << " " * (label_width - Term.width(label) + 2)
            indent = INDENT + label_width + 2
            buf << Term.wrap(flag.help, width - indent).gsub("\n", "\n#{" " * indent}")
          end
          buf << "\n"
        end
        buf << separator_text(config.flags.length)

        buf.string
      end

      # Build the usage line from the configured app name and positionals.
      def banner
        text = config.banner
        text ||= [color.blue("Usage:"), color.green(config.app_name), "[options]"].tap do
          _1.push(*config.positionals.map(&:meta))
        end.join(" ")
        Term.wrap(text, width)
      end

      # Render separator text at its recorded position between flags.
      def separator_text(position)
        StringIO.new.tap do |buf|
          config.separators.each do |(pos, str)|
            if pos == position
              buf << color.blue(str)
              buf << "\n"
            end
          end
        end.string
      end

      # one-liners
      def color = @color ||= Color.new(config.color)
      def widest_label = config.flags.map { Term.width(flag_label(_1)) }.max

      protected

      def flag_label(flag)
        label = flag.switches.map { color.green(_1) }.join(", ")
        return label unless flag.takes_param?
        "#{label} #{color.yellow("<#{flag.meta}>")}"
      end
    end
  end
end
