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
      attr_reader :cmd, :config

      def initialize = @config = Config.new
      def app_name = config.app_name

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
          cmd = config.commands[argv.first&.to_sym] || config
          puts Help.new(cmd)
          return true
        end
        if config.version && (argv.include?("--version") || argv.include?("-v"))
          puts "#{app_name} #{config.version}"
          return true
        end
      end

      # Peek at the first bare argument to pick a subcommand, then parse the
      # rest with its own Config and merge the two option hashes together.
      def subcommand(argv)
        # do our "main" parse before we hit a subcommand
        main = parse_with_cmd(config, argv, passthru: true)
        name, *rest = main[:_args]
        name = name&.to_sym
        raise NakedRequested if !name

        # find/parse cmd
        cmd = config.commands[name]
        raise Error, "unknown command '#{name}'" if !cmd
        cmd_options = parse_with_cmd(cmd, rest)

        # merge
        main.merge(cmd_options).merge(command: name)
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
          warn "#{cmd.app_name}: #{ex.message}"
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
      # with_cmd and friends. Used for both main cmd and subcommands. Keep track
      # of which command (config) we are workong on, so we can handle errors
      # appropriately.
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
