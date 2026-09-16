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
        help = [].tap do
          _1 << desc if config.desc
          _1 << banner
          _1 << commands_text if config.commands.any?
          _1 << flags_text(config, "Options:", builtins: !config.parent)
          _1 << flags_text(config.parent, "Other options:") if config.parent
        end.compact.join("\n\n")
        "#{help}\n"
      end

      # Render a heading and aligned flags, preserving explicit separator lines.
      def flags_text(source, title, builtins: true)
        flags = source.flags
        flags -= [source.help_flag, source.version_flag] unless builtins
        return if flags.empty? && source.separators.empty?
        lines = [color.blue(title)]
        label_width = flags.map { Term.width(flag_label(_1)) }.max
        flags.each.with_index do |flag, idx|
          lines.concat(separator_lines(source, idx))
          buf = StringIO.new

          # left
          label = flag_label(flag)
          buf << " " * INDENT
          buf << label

          # right
          help = flag.help
          if flag.env
            env_help = "[env: #{flag.env}]"
            help = help ? "#{help} #{env_help}" : env_help
          end
          if help
            buf << " " * (label_width - Term.width(label) + 2)
            indent = INDENT + label_width + 2
            buf << Term.wrap(help, width - indent).gsub("\n", "\n#{" " * indent}")
          end
          lines << buf.string
        end
        lines.concat(separator_lines(source, flags.length))

        lines.join("\n")
      end

      # Build the usage line from the configured app name and positionals.
      def banner
        text = config.banner
        text ||= [color.blue("Usage:"), color.green(config.app_name), "[options]"].tap do
          _1.push(*config.positionals.map(&:meta))
          _1.push(color.yellow("<command>")) if config.commands.any?
        end.join(" ")
        Term.wrap(text, width)
      end

      # Render the list of subcommands, aligned like the flag list above.
      def commands_text
        lines = [color.blue("Commands:")]
        label_width = config.commands.keys.map { Term.width(_1.to_s) }.max
        config.commands.each do |name, sub|
          lines << StringIO.new.tap do |buf|
            buf << " " * INDENT << color.green(name.to_s)
            if sub.desc
              buf << " " * (label_width - Term.width(name.to_s) + 2)
              indent = INDENT + label_width + 2
              buf << Term.wrap(sub.desc, width - indent).gsub("\n", "\n#{" " * indent}")
            end
          end.string
        end
        lines.join("\n")
      end

      # Keep blank and multiline separators exactly as supplied.
      def separator_lines(source, position)
        source.separators.filter_map { |pos, str| color.blue(str) if pos == position }
      end

      # one-liners
      def color = @color ||= Color.new(config.color)
      def desc = Term.wrap(config.desc, width)

      protected

      def flag_label(flag)
        label = flag.switches.map { color.green(_1) }.join(", ")
        return label unless flag.takes_param?
        "#{label} #{color.yellow("<#{flag.meta}>")}"
      end
    end
  end
end
