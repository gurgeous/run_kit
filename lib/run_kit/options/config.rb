#
# Config users setup with `RunKit::Options.parse`. Records flags, positionals, help text,
# etc.
#

module RunKit
  module Options
    class Config
      attr_accessor :app_name, :banner, :color, :desc, :exit, :help, :naked, :validate, :version
      attr_reader :commands, :flags, :help_flag, :lookup, :positionals, :separators, :version_flag
      alias_method :naked?, :naked

      def initialize
        @app_name = File.basename($PROGRAM_NAME)
        @naked = true
        @lookup = {}
        @commands, @flags, @positionals, @separators = {}, [], [], []
      end

      # Add a positional param declared as `<url>`.
      def pos(meta, help = "")
        Positional.new(meta:, help:).tap do
          raise ArgumentError, "duplicate positional #{_1.key}" if key?(_1.key)
          positionals << _1
          lookup[_1.key] = _1
        end
      end

      # Add a subcommand with its own nested Config, eg `myapp build`.
      def cmd(name, desc = nil)
        name = name.to_sym
        raise ArgumentError, "duplicate command #{name}" if commands.key?(name)
        Config.new.tap do
          _1.desc = desc
          yield _1 if block_given?
          raise ArgumentError, "nested commands are not supported" if _1.commands.any?
          commands[name] = _1
        end
      end

      # Add separator text at the current point in generated help.
      def sep(text = "")
        [flags.length, text].tap do
          separators << _1
        end
      end

      #
      # flags
      #

      def bool(*opts, default: nil, required: false, env: nil)
        add_flag(Flag.new(:bool, opts, default:, required:, env:))
      end

      def float(*opts, default: nil, required: false, choices: nil, env: nil)
        add_flag(Flag.new(:float, opts, default:, required:, choices:, env:))
      end

      def int(*opts, default: nil, required: false, choices: nil, env: nil)
        add_flag(Flag.new(:int, opts, default:, required:, choices:, env:))
      end

      def path(*opts, default: nil, required: false, choices: nil, env: nil)
        add_flag(Flag.new(:path, opts, default:, required:, choices:, env:))
      end

      def str(*opts, default: nil, required: false, choices: nil, env: nil)
        add_flag(Flag.new(:str, opts, default:, required:, choices:, env:))
      end

      def sym(*opts, default: nil, required: false, choices: nil, env: nil)
        add_flag(Flag.new(:sym, opts, default:, required:, choices:, env:))
      end

      # long-form aliases
      alias_method :boolean, :bool
      alias_method :command, :cmd
      alias_method :integer, :int
      alias_method :pathname, :path
      alias_method :positional, :pos
      alias_method :separator, :sep
      alias_method :string, :str
      alias_method :symbol, :sym

      # handy helpers
      def defaults
        flags.filter_map do
          next if _1.required || _1 == help_flag || _1 == version_flag
          [_1.key, _1.default]
        end.to_h
      end

      # one-liners
      def flag(switch) = lookup[switch]
      def flag?(switch) = lookup.key?(switch)
      def key?(key) = lookup.key?(key)
      def naked_message = "#{app_name}: try '#{app_name} --help' for more information"
      def required = flags.select(&:required?)

      # Complete one-time setup after the caller has declared overrides.
      def prepare!
        return if @prepared
        @prepared = true
        @exit ||= lambda { |status| Kernel.exit(status) }
        @help_flag = bool("-h", "--help", "Show this message")
        @version_flag = bool("-v", "--version", "Show version") if version

        # prepare subcmds, mostly including copying things from parent
        commands.each do |name, cmd|
          cmd.app_name = "#{app_name} #{name}"
          cmd.color, cmd.exit, cmd.version = color, exit, version
          cmd.prepare!
        end
      end

      protected

      def add_flag(flag)
        # dup check
        raise ArgumentError, "reserved flag key: _args" if flag.key == :_args
        raise ArgumentError, "dup flag key: #{flag.key}" if key?(flag.key)
        flag.switches.each do
          raise ArgumentError, "dup flag switch: #{_1}" if flag?(_1)
        end

        # append
        flags << flag
        lookup[flag.key] = flag
        flag.switches.each { lookup[_1] = flag }

        # return flag
        flag
      end
    end
  end
end
