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
      # root is the top-level config; ctx is the active parser or validator's config.
      attr_reader :ctx, :root

      def initialize = @root = Config.new

      # Parse argv and turn internal parser outcomes into CLI behavior.
      def parse(argv)
        @ctx = root
        root.prepare!

        # handle --help and --version
        return exit_fn(0) if early_exit?(argv)

        begin
          options = root.commands.empty? ? parse_with_ctx(root, argv) : subcommand(argv)
          klass = Data.define(*options.keys)
          klass.new(**options).tap { validate(_1) }
        rescue Error, HelpRequested => ex
          handle_error(ex)
        end
      end

      protected

      # Handle --help or --version
      def early_exit?(argv)
        if argv.include?("--help") || argv.include?("-h")
          selected = root.commands[argv.first] || root
          puts Help.new(selected)
          return true
        end
        if root.version && (argv.include?("--version") || argv.include?("-v"))
          puts "#{root.name} #{root.version}"
          return true
        end
      end

      # Select from the first argument, then parse global and command flags together.
      def subcommand(argv)
        rest = argv
        if (child = root.commands[rest.first])
          rest = rest.drop(1)
          infer_help = false
        else
          child = root.default_command
          infer_help = true
        end
        raise HelpRequested if !child && rest.empty?
        if !child
          switch = rest.first.start_with?("--") ? rest.first.split("=", 2).first : rest.first[0, 2]
          raise Error, "global options must follow the command" if root.key?(switch)
          raise Error, "unknown command '#{rest.first}'"
        end
        parse_with_ctx(child, rest, infer_help:).merge(command: child.name)
      end

      # Validate the final options, root first.
      def validate(options)
        [ctx.root, ctx].compact.each do
          validate_with_ctx(_1, options)
        rescue RuntimeError => ex
          raise Error, ex.message
        end
      end

      # Render the outcome using the active context.
      def handle_error(ex)
        if ex.is_a?(Error)
          warn "#{ctx.full_name}: #{ex.message}"
          warn "#{ctx.full_name}: try '#{ctx.full_name} --help' for more information"
          return exit_fn(2, error: ex.message)
        end

        # Inferred help on a bare invocation introduces the whole app.
        puts Help.new(root)
        exit_fn(0)
      end

      def exit_fn(status, error: nil)
        args = [].tap do
          _1 << status
          _1 << error if root.exit.arity == 2
        end
        root.exit.call(*args)
        nil
      end

      #
      # Keep the active config after a failure so the outer rescue can use it.
      # This is error context, not a push/pop command stack.
      #

      def with_ctx(ctx)
        @ctx = ctx
        yield
      end

      def parse_with_ctx(ctx, argv, infer_help: true)
        with_ctx(ctx) do
          Parser.new(ctx).parse(argv, infer_help:)
        end
      end

      def validate_with_ctx(ctx, options)
        with_ctx(ctx) do
          ctx.validate&.call(options)
        end
      end
    end

    class Error < StandardError; end
    class HelpRequested < Exception; end # rubocop:disable Lint/InheritException

    # main entry point
    def self.parse(argv = ARGV)
      Main.new.tap { yield _1.root if block_given? }.parse(argv)
    end
  end
end
