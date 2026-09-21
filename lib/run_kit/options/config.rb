#
# Config users setup with `RunKit::Options.parse`. Records flags, positionals, help text,
# etc.
#

module RunKit
  module Options
    class Config
      attr_accessor :banner, :color, :default, :desc, :exit, :help, :root, :validate, :version
      attr_reader(*%i[help_flag name version_flag])
      alias_method :default?, :default

      def initialize(name: nil)
        self.name = name || Shell.program_name
      end

      def name=(name)
        @name = name.to_s
      end

      # Add a positional param declared as `<url>`.
      def pos(meta, help = "")
        check_inside!
        if positionals.last&.variadic?
          raise ArgumentError, "no positional arguments are allowed after #{positionals.last.meta}"
        end
        Positional.new(meta:, help:).tap do
          raise ArgumentError, "duplicate positional #{_1.key}" if key?(_1.key)
          positionals << _1
          lookup[_1.key] = _1
        end
      end

      # Add a subcommand with its own nested Config, eg `myapp build`.
      def cmd(name, desc = nil, default: false)
        check_inside!
        name = name.to_s
        raise ArgumentError, "duplicate command #{name}" if commands.key?(name)
        raise ArgumentError, "default command already set" if default && default_command
        Config.new(name:).tap do |child|
          child.default, child.desc, child.root = default, desc, self
          with_inside(name) { yield child } if block_given?
          raise ArgumentError, "nested commands are not supported" if child.commands.any?
          commands[name] = child
        end
      end

      # Add separator text at the current point in generated help.
      def sep(text = "")
        check_inside!
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
      alias_method :app_name=, :name=
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
      def default_command = commands.values.find(&:default?)
      def full_name = root ? "#{root.full_name} #{name}" : name
      def key?(key) = lookup.key?(key)

      # memoized accessors
      def commands = @commands ||= {}
      def flags = @flags ||= []
      def lookup = @lookup ||= {}
      def positionals = @positionals ||= []
      def separators = @separators ||= []

      # Complete one-time setup after the caller has declared overrides.
      def prepare!
        return if @prepared
        if commands.any? && positionals.any?
          raise ArgumentError, "a command with subcommands cannot also take positional arguments; add them to a subcommand instead"
        end
        @prepared = true

        # Children inherit shared settings before adding builtins.
        if root
          self.color, self.exit, self.version = root.color, root.exit, root.version
        end

        # now defaults
        @exit ||= lambda { |status| Kernel.exit(status) }
        @help_flag = bool("-h", "--help", "Show this message")
        @version_flag = bool("-v", "--version", "Show version") if version

        # Global and command flags share one parser; only builtins may overlap.
        if root
          keys = lookup.keys - [help_flag, version_flag].compact.flat_map { [_1.key, *_1.switches] }
          collisions = keys & root.lookup.keys
          raise ArgumentError, "command #{name} conflicts with global options: #{collisions.join(", ")}" if collisions.any?
        end

        # setup subcommands
        commands.each_value(&:prepare!)
      end

      protected

      # Catch accidental use of the outer config while defining a command.
      def with_inside(name)
        @inside = name
        yield
      ensure
        @inside = nil
      end

      def check_inside!
        raise ArgumentError, "you're adding a root option inside #{@inside.inspect} command" if @inside
      end

      def add_flag(flag)
        check_inside!
        # dup check
        raise ArgumentError, "reserved flag key: _args" if flag.key == :_args
        raise ArgumentError, "dup flag key: #{flag.key}" if key?(flag.key)
        flag.switches.each do
          raise ArgumentError, "dup flag switch: #{_1}" if key?(_1)
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
