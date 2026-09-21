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
      # passthru is set, scanning halts at the first bare arg (for subcommands).
      def parse(argv, passthru: false, infer_help: true)
        # 1. Parse argv.
        argv_options = parse_argv(argv, passthru:)

        # 2. defaults => ENV => ARGV
        options = {}.merge(config.defaults, parse_env, argv_options)

        # 3. Validate requirements after ENV resolution; bare missing inputs show help.
        validate!(options, infer_help: infer_help && argv.empty?)

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
            # An unknown root switch starts the default command's arguments.
            if passthru && config.default_command && item.start_with?("-") && item != "--"
              switch = item.start_with?("--") ? item.split("=", 2).first : item[0, 2]
              if !config.flag?(switch) && !find_negated_flag(switch)
                break operands.concat([item, *queue])
              end
            end

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

      def find_negated_flag(switch)
        if (m = Flag::NEGATE_RE.match(switch))
          flag = config.flag("--#{m[1]}")
          flag if flag&.bool?
        end
      end

      def validate!(options, infer_help: false)
        # Infer help only for missing inputs, after ENV has been resolved.
        config.required.each do
          next if options.key?(_1.key)
          raise HelpRequested if infer_help
          raise Error, "required option '#{_1.switch}' is missing"
        end
        config.positionals.each do
          next if options[_1.key]
          raise HelpRequested if infer_help
          raise Error, "required argument '#{_1.meta}' is missing"
        end
      end
    end
  end
end
