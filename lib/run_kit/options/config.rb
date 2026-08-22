#
# Config users setup with `RunKit::Options.parse`. Records flags, positionals, help text,
# etc.
#

module RunKit
  module Options
    class Config
      attr_accessor :app_name, :banner, :color, :exit, :help, :naked, :version
      attr_reader :flags, :help_flag, :lookup, :positionals, :separators, :version_flag
      alias_method :naked?, :naked

      def initialize
        @app_name = File.basename($PROGRAM_NAME)
        @naked = true
        @lookup = {}
        @flags, @positionals, @separators = [], [], []
      end

      # Add a positional param declared as `<url>`.
      def pos(meta, help = "")
        Positional.new(meta:, help:).tap do
          raise ArgumentError, "duplicate positional #{_1.key}" if key?(_1.key)
          positionals << _1
          lookup[_1.key] = _1
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

      def bool(*opts, default: nil, required: false)
        add_flag(Flag.new(:bool, opts, default:, required:))
      end

      def float(*opts, default: nil, required: false, choices: nil)
        add_flag(Flag.new(:float, opts, default:, required:, choices:))
      end

      def int(*opts, default: nil, required: false, choices: nil)
        add_flag(Flag.new(:int, opts, default:, required:, choices:))
      end

      def path(*opts, default: nil, required: false, choices: nil)
        add_flag(Flag.new(:path, opts, default:, required:, choices:))
      end

      def str(*opts, default: nil, required: false, choices: nil)
        add_flag(Flag.new(:str, opts, default:, required:, choices:))
      end

      def sym(*opts, default: nil, required: false, choices: nil)
        add_flag(Flag.new(:sym, opts, default:, required:, choices:))
      end

      # long-form aliases
      alias_method :boolean, :bool
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
      def required = flags.select(&:required?)

      # Complete one-time setup after the caller has declared overrides.
      def prepare!
        return if @prepared
        @prepared = true
        @exit ||= lambda { |status| Kernel.exit(status) }
        @help_flag = add_builtin(["-h", "--help"], "Show this message")
        @version_flag = add_builtin(["-v", "--version"], "Show version") if version
      end

      protected

      # Add help/version flags, but only for switches the user did not override.
      def add_builtin(switches, help_text)
        unused = switches.select { !flag?(_1) }
        return if unused.empty?
        add_flag(Flag.new(:bool, unused + [help_text]))
      end

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
