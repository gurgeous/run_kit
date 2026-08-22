#
# Turns argv into a typed result. It knows the CLI grammar but stays away from
# printing and exiting.
#

module RunKit
  module Options
    class Parser
      attr_reader :config, :options, :queue

      def initialize(config)
        @config = config
      end

      # Reset transient state, parse argv, and assemble the result.
      def parse(argv)
        @options, @queue = config.defaults, argv.dup
        parse_queue
        validate!
        options
      end

      protected

      #
      # main parser
      #

      def parse_queue
        raise NakedRequested if config.naked? && queue.empty?

        # any non-flags we find below
        operands = []

        # process argv as queue
        while (item = queue.shift)
          case item
          when Flag::SWITCH_RE, Flag::INLINE_RE then parse_switch(item, Regexp.last_match)
          when /\A-[^-]/ then parse_smashed(item)
          when "", /\A[^-]/ then operands << item
          when "--" then break operands.concat(queue)
          else; raise Error, "unexpected argument '#{item}' found"
          end
        end

        # add pred? for bools
        config.flags.filter_map { _1.key if _1.bool? }.each do
          options[:"#{_1}?"] = options[_1] if options.key?(_1)
        end

        # positionals
        config.positionals.each do
          options[_1.key] = operands.shift
        end

        # _args
        options[:_args] = operands
      end

      #
      # -x or -x=123 or --xyz or --xyz=123 or --no-xyz
      #

      def parse_switch(item, match)
        switch = "-#{match[1]}"
        param = match[2]
        separator = param ? "=" : ""

        # -x or --xyz?
        if (flag = config.flag(switch))
          builtin!(flag)
          param = queue.shift if flag.takes_param? && separator.empty?
          options[flag.key] = flag.parse(switch, param)
          return
        end

        # --no-xyz?
        if (neg = find_negated_flag(switch))
          raise Error, "option '#{item}' does not take a value" if separator == "="
          options[neg.key] = false
          return
        end

        raise Error, "unexpected argument '#{item}' found"
      end

      #
      # smashed flags
      #

      # Expand short-switch groups such as `-qv`. A parameter-taking switch ends
      # the group and consumes either its attached suffix or the next queue item.
      def parse_smashed(group)
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
            options[flag.key] = flag.parse(switch, param)
            return
          end

          # bool
          options[flag.key] = true
        end
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

      def validate!
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
