#
# Main entry point and parsing
#
#
# Glossary
#
# | term       | meaning                            | example                   |
# |------------|------------------------------------|---------------------------|
# | flag       | configured cli flag                | o.int "-p", "--port"      |
# | switch     | dashed string invoking a flag      | -p or --port              |
# | key        | result field derived from a switch | --http-port => :http_port |
# | param      | raw input consumed by a flag       | 8080 from --port=8080     |
# | -          | -                                  | -                         |
# | app_name   | program name used in output        | "curl"                    |
# | banner     | usage text at top of help          | Usage: curl [options]     |
# | meta       | placeholder shown for a param      | <xxx> from `--port <xxx>` |
# | positional | configured required param slot     | o.positional "<url>"      |
# | separator  | help section heading               | "Network:"                |
# | command    | subcommand with its own Config     | o.cmd "build" { ... }     |
#

module RunKit
  module Options
    class Main
      # config is the root; cmd is the active parser or validator's config.
      attr_reader :cmd, :config

      def initialize = @config = Config.new
      def full_name = config.full_name

      # Parse argv and turn internal parser outcomes into CLI behavior.
      def parse(argv)
        config.prepare!

        # handle --help and --version
        return exit_fn(0) if early_exit?(argv)

        begin
          options = config.commands.empty? ? parse_with_cmd(config, argv) : subcommand(argv)
          klass = Data.define(*options.keys)
          klass.new(**options).tap { validate(_1) }
        rescue Error, NakedRequested => ex
          handle_error(ex)
        end
      end

      protected

      # Handle --help or --version
      def early_exit?(argv)
        if argv.include?("--help") || argv.include?("-h")
          selected = config.commands[argv.first] || config
          puts Help.new(selected)
          return true
        end
        if config.version && (argv.include?("--version") || argv.include?("-v"))
          puts "#{full_name} #{config.version}"
          return true
        end
      end

      # Peek at the first bare argument to pick a subcommand, then parse the
      # rest with its own Config and merge the two option hashes together.
      def subcommand(argv)
        # Parse root options before the subcommand.
        root_options = parse_with_cmd(config, argv, passthru: true)
        name, *rest = root_options[:_args]
        raise NakedRequested if !name

        # Find and parse the child.
        child = config.commands[name]
        raise Error, "unknown command '#{name}'" if !child
        child_options = parse_with_cmd(child, rest)

        # merge
        root_options.merge(child_options).merge(command: name)
      end

      # Validate the final options, root first.
      def validate(options)
        [cmd.parent, cmd].compact.each do
          validate_with_cmd(_1, options)
        rescue RuntimeError => ex
          raise Error, ex.message
        end
      end

      # Render the outcome using the active cmd.
      def handle_error(ex)
        if ex.is_a?(Error)
          warn "#{cmd.full_name}: #{ex.message}"
          warn cmd.naked_message
          return exit_fn(1, error: ex.message)
        end

        puts Help.new(cmd)
        exit_fn(0)
      end

      def exit_fn(status, error: nil)
        args = [].tap do
          _1 << status
          _1 << error if config.exit.arity == 2
        end
        config.exit.call(*args)
        nil
      end

      #
      # Keep the active config after a failure so the outer rescue can use it.
      # This is error context, not a push/pop command stack.
      #

      def with_cmd(cmd)
        @cmd = cmd
        yield
      end

      def parse_with_cmd(cmd, argv, passthru: false)
        with_cmd(cmd) do
          Parser.new(cmd).parse(argv, passthru:)
        end
      end

      def validate_with_cmd(cmd, options)
        with_cmd(cmd) do
          cmd.validate&.call(options)
        end
      end
    end

    class Error < StandardError; end
    class NakedRequested < Exception; end # rubocop:disable Lint/InheritException

    # main entry point
    def self.parse(argv = ARGV)
      Main.new.tap { yield _1.config if block_given? }.parse(argv)
    end
  end
end
