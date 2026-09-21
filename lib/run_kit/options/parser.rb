#
# Turns argv into a typed result. It knows the CLI grammar but stays away from
# printing and exiting.
#

module RunKit
  module Options
    class Parser
      attr_reader(*%i[config flags lookup])

      def initialize(config)
        @config = config
        @flags = config.root ? (config.root.flags - [config.root.help_flag, config.root.version_flag]) + config.flags : config.flags
        @lookup = (config.root&.lookup || {}).merge(config.lookup)
      end

      # Parse global and command flags together, then assemble the result.
      def parse(argv, infer_help: true)
        # 1. Parse argv.
        argv_options = parse_argv(argv)

        # 2. defaults => ENV => ARGV
        options = {}.merge(config.root&.defaults || {}, config.defaults, parse_env, argv_options)

        # 3. Validate requirements after ENV resolution; bare missing inputs show help.
        validate!(options, infer_help: infer_help && argv.empty?)

        # success! add predicate? keys
        flags.select(&:bool?).map(&:key).each do
          options[:"#{_1}?"] = options[_1] if options.key?(_1)
        end

        options
      end

      protected

      #
      # main parser
      #

      def parse_argv(argv)
        {}.tap do |result|
          # any non-flags we find below
          args = []

          # process argv as queue
          queue = argv.dup
          while (item = queue.shift)
            case item
            when Flag::SWITCH_RE, Flag::INLINE_RE then result.merge!(parse_switch(item, Regexp.last_match, queue))
            when /\A-[^-]/ then result.merge!(parse_smashed(item, queue))
            when "", /\A[^-]/
              args << item
            when "--" then break args.concat(queue)
            else; raise Error, "unexpected argument '#{item}' found"
            end
          end

          # positionals
          config.positionals.each { result[_1.key] = _1.variadic? ? args.shift(args.length) : args.shift }
          if config.positionals.any? && args.any?
            raise Error, "unexpected argument '#{args.first}' found"
          end

          # _args
          result[:_args] = args
        end
      end

      #
      # -x or -x=123 or --xyz or --xyz=123
      #

      def parse_switch(item, match, queue)
        switch = "-#{match[1]}"
        param = match[2]

        # -x or --xyz?
        if (flag = lookup[switch])
          param = queue.shift if flag.takes_param? && !param
          return {flag.key => flag.parse(switch, param)}
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
          flag = lookup[switch]
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
        flags.select { _1.env && ENV.key?(_1.env) }.map do |flag|
          [flag.key, flag.parse_env(ENV[flag.env])]
        end.to_h
      end

      #
      # helpers
      #

      def validate!(options, infer_help: false)
        # Infer help only for missing inputs, after ENV has been resolved.
        flags.select(&:required?).each do
          next if options.key?(_1.key)
          raise HelpRequested if infer_help
          raise Error, "required option '#{_1.switch}' is missing"
        end
        config.positionals.each do
          next if _1.variadic? ? options[_1.key].any? : options[_1.key]
          raise HelpRequested if infer_help
          raise Error, "required argument '#{_1.meta}' is missing"
        end
      end
    end
  end
end
