#
# One configured flag, including all switches that invoke it.
#

module RunKit
  module Options
    class Flag
      # --foo or -f
      SWITCH_RE = /\A-(\w|-\w[\w-]*)\z/
      # --foo=bar
      INLINE_RE = /\A-(\w|-\w[\w-]*)=(.*)\z/m

      TRUE_ENV = %w[1 true yes on]
      FALSE_ENV = ["", "0", "false", "no", "off"]
      KINDS = %i[bool float int path str sym]

      attr_reader(*%i[choices default env help kind meta required switches])

      # ctor
      def initialize(kind, opts, default: nil, required: false, choices: nil, env: nil)
        @choices, @kind, @required = choices, kind, required

        # extract @help from last string
        @switches = opts.dup
        @help = if switch && !switch.start_with?("-")
          switches.pop
        end

        # Extract meta from the final switch, if written as `--port <int>`.
        @meta = build_meta
        validate_switches!
        @env = (env == true) ? key.to_s.upcase : env

        # default, with some special handling for bool
        @default = default
        if bool? && default.nil? && !required?
          @default = false
        end

        validate
      rescue ArgumentError => ex
        ctx = reconstruct(kind, opts, default:, required:, choices:, env:)
        raise ArgumentError, "#{ctx} - #{ex.message}", cause: nil
      end

      #
      # parsing
      #

      # Parse a single cli param
      def parse(switch, param)
        if bool?
          raise Error, "option '#{switch}=#{param}' does not take a value" if param
          return true
        end

        raise Error, "option '#{switch}' requires a value" if !param
        parse_value(param, "option '#{switch}'")
      end

      # Parse a value supplied by ENV[$SOMETHING]
      def parse_env(param)
        source = "environment variable '#{env}'"

        # special handling for bools
        if bool?
          return true if TRUE_ENV.include?(param.downcase)
          return false if FALSE_ENV.include?(param.downcase)
          raise Error, "invalid value '#{param}' for #{source}"
        end

        parse_value(param, source)
      end

      # one-liners
      def bool? = kind == :bool
      def key = @key ||= switch.sub(/^-+/, "").tr("-", "_").to_sym
      def switch = switches.last
      def takes_param? = !bool?
      alias_method :required?, :required

      protected

      #
      # validation
      #

      def validate_switches!
        switches.each do
          raise ArgumentError, "invalid switch: #{_1}" unless _1.is_a?(String)
          raise ArgumentError, "invalid switch: #{_1}" unless _1.match?(SWITCH_RE)
        end
        raise ArgumentError, 'flag must start with "-" or "--"' if switches.empty?
        raise ArgumentError, "duplicate switch" unless switches.uniq.length == switches.length
      end

      def validate
        # params
        raise ArgumentError, "invalid flag kind: #{kind}" unless KINDS.include?(kind)
        raise ArgumentError, "boolean flags do not accept meta" if bool? && meta
        raise ArgumentError, "required must be true or false" unless required == true || required == false
        raise ArgumentError, "required flags cannot have defaults" if required && default != nil
        raise ArgumentError, "invalid default #{default.inspect} for #{kind}" if default != nil && !allowed?(default)
        raise ArgumentError, "env must be true or a string" unless env.nil? || env.is_a?(String)

        # choices
        if choices
          raise ArgumentError, "choices must be an array" unless choices.is_a?(Array)
          raise ArgumentError, "choices cannot be empty" if choices.empty?
          choices.each do
            raise ArgumentError, "invalid choice #{_1.inspect} for #{kind}" unless allowed?(_1)
          end
        end
      end

      #
      # helpers
      #

      # Use the original declaration, before metadata and ENV normalization.
      def reconstruct(kind, opts, **settings)
        args = opts.map(&:inspect) + settings.filter_map { "#{_1}: #{_2.inspect}" if _2 }
        ["opt.#{kind}", args.join(", ")].reject(&:empty?).join(" ")
      end

      def build_meta
        # Only the final spelling may carry an inferred `<meta>`.
        if (m = /\A(\S+) <([^>]+)>\z/.match(switch))
          switches[switches.length - 1] = m[1]
          return m[2]
        end
        kind.to_s unless bool?
      end

      def allowed?(candidate)
        case kind
        when :bool then candidate == true || candidate == false
        when :float then candidate.is_a?(Float)
        when :int then candidate.is_a?(Integer)
        when :path then candidate.is_a?(Pathname)
        when :str then candidate.is_a?(String)
        when :sym then candidate.is_a?(Symbol)
        end
      end

      def parse_value(param, source)
        parsed = begin
          case kind
          when :float then Float(param)
          when :int then Integer(param, 10)
          when :path then Pathname.new(param)
          when :str then param
          when :sym then param.to_sym
          end
        rescue ArgumentError
          raise Error, "invalid value '#{param}' for #{source}"
        end

        if choices && !choices.include?(parsed)
          raise Error, "invalid value '#{parsed}' for #{source}, must be one of #{choices.join(", ")}"
        end
        parsed
      end
    end
  end
end
