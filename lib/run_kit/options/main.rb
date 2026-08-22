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
#

module RunKit
  module Options
    class Main
      attr_reader :config

      def initialize = @config = Config.new
      def app_name = config.app_name

      # Parse argv and turn internal parser outcomes into CLI behavior.
      def parse(argv)
        config.prepare!

        begin
          options = Parser.new(config).parse(argv)
          klass = Data.define(*options.keys)
          klass.new(**options)
        rescue Error => ex
          warn "#{app_name}: #{ex.message}"
          warn "#{app_name}: try '#{app_name} --help' for more information"
          exit_fn(1, error: ex.message)
        rescue HelpRequested, NakedRequested, VersionRequested => ex
          early_exit(ex)
          exit_fn(0)
        end
      end

      protected

      def early_exit(ex)
        case ex
        when HelpRequested
          puts Help.new(config)
        when NakedRequested
          puts "#{app_name}: try '#{app_name} --help' for more information"
        when VersionRequested
          puts "#{app_name} #{config.version}"
        end
      end

      def exit_fn(status, error: nil)
        args = [].tap do
          _1 << status
          _1 << error if config.exit.arity == 2
        end
        config.exit.call(*args)
        nil
      end
    end

    class Error < StandardError; end

    # early exits
    class HelpRequested < Exception; end # rubocop:disable Lint/InheritException
    class NakedRequested < Exception; end # rubocop:disable Lint/InheritException
    class VersionRequested < Exception; end # rubocop:disable Lint/InheritException

    # main entry point
    def self.parse(argv = ARGV)
      Main.new.tap { yield _1.config if block_given? }.parse(argv)
    end
  end
end
