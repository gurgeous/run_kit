#
# Turns argv into a typed result. It knows the CLI grammar but stays away from
# printing and exiting.
#

module RunKit
  module Options
    class Parser
      attr_reader :config

      def initialize(config)
        @config = config
      end

      # Reset transient state, parse argv, and assemble the result. When
      # passthru is set, flag scanning halts at the first bare argument, so a
      # subcommand token (and everything after it, `-h` included) passes
      # through untouched for a later parser to handle.
      def parse(argv, passthru: false)
        # 1. naked?
        raise NakedRequested if config.naked? && argv.empty?

        # 2. Parse argv. We do this first, because other things can raise and
        # --help should trump other issues.
        argv_options = parse_argv(argv, passthru:)

        # 3. defaults => ENV => ARGV
        options = {}.merge(config.defaults, parse_env, argv_options)

        # 4. validate final options
        validate!(options)

        # success! add predicate? keys
        config.flags.select(&:bool?).map(&:key).each do
          options[:"#{_1}?"] = options[_1] if options.key?(_1)
        end

        options
      end

      protected

      #
      # main parser
      #

      def parse_argv(argv, passthru: false)
        {}.tap do |result|
          # any non-flags we find below
          operands = []

          # process argv as queue
          queue = argv.dup
          while (item = queue.shift)
            case item
            when Flag::SWITCH_RE, Flag::INLINE_RE then result.merge!(parse_switch(item, Regexp.last_match, queue))
            when /\A-[^-]/ then result.merge!(parse_smashed(item, queue))
            when "", /\A[^-]/
              operands << item
              if passthru
                operands.concat(queue)
                break
              end
            when "--" then break operands.concat(queue)
            else; raise Error, "unexpected argument '#{item}' found"
            end
          end

          # positionals
          config.positionals.each { result[_1.key] = operands.shift }

          # _args
          result[:_args] = operands
        end
      end

      #
      # -x or -x=123 or --xyz or --xyz=123 or --no-xyz
      #

      def parse_switch(item, match, queue)
        switch = "-#{match[1]}"
        param = match[2]
        separator = param ? "=" : ""

        # -x or --xyz?
        if (flag = config.flag(switch))
          builtin!(flag)
          param = queue.shift if flag.takes_param? && separator.empty?
          return {flag.key => flag.parse(switch, param)}
        end

        # --no-xyz?
        if (neg = find_negated_flag(switch))
          raise Error, "option '#{item}' does not take a value" if separator == "="
          return {neg.key => false}
        end

        raise Error, "unexpected argument '#{item}' found"
      end

      #
      # smashed flags
      #

      # Expand short-switch groups such as `-qv`. A parameter-taking switch ends
      # the group and consumes either its attached suffix or the next queue item.
      def parse_smashed(group, queue)
        result = {}
        (1...group.length).each do |idx|
          switch = "-#{group[idx]}"
          flag = config.flag(switch)
          raise Error, "unexpected argument '#{group}' found" unless flag
          builtin!(flag)

          # For `-qnLee`, `Lee` belongs to `-n`; for `-qn Lee`, shift the queue.
          if flag.takes_param?
            param = if idx + 1 < group.length
              group[idx + 1...group.length]
            else
              queue.shift
            end
            result[flag.key] = flag.parse(switch, param)
            return result
          end

          # bool
          result[flag.key] = true
        end
        result
      end

      #
      # env
      #

      def parse_env
        config.flags.select { _1.env && ENV.key?(_1.env) }.map do |flag|
          [flag.key, flag.parse_env(ENV[flag.env])]
        end.to_h
      end

      #
      # helpers
      #

      def builtin!(flag)
        raise HelpRequested if flag == config.help_flag
        raise VersionRequested if flag == config.version_flag
      end

      def find_negated_flag(switch)
        if (m = Flag::NEGATE_RE.match(switch))
          flag = config.flag("--#{m[1]}")
          flag if flag&.bool?
        end
      end

      def validate!(options)
        config.required.each do
          raise Error, "required option '#{_1.switch}' is missing" if !options.key?(_1.key)
        end
        config.positionals.each do
          raise Error, "required argument '#{_1.meta}' is missing" if !options[_1.key]
        end
      end
    end
  end
end
