require "run_kit"

module RunKit
  module Options
    class ParserTest < Minitest::Test
      def test_basic
        argv = [
          "-vnLee",
          "--count=2",
          "--mode", "fast",
          "--no-quiet",
          "--output", "tmp/out",
          "source.txt",
        ]
        config = Config.new.tap do
          _1.bool("-v", "--verbose")
          _1.str("-n", "--name")
          _1.int("--count", choices: [1, 2])
          _1.float("--ratio", default: 1.5)
          _1.sym("--mode", choices: %i[slow fast])
          _1.bool("--quiet", required: true)
          _1.path("--output")
          _1.pos("<source>")
        end

        options = Parser.new(config).parse(argv)

        assert_equal({
          verbose: true,
          name: "Lee",
          count: 2,
          ratio: 1.5,
          mode: :fast,
          quiet: false,
          output: Pathname("tmp/out"),
          source: "source.txt",
          _args: [],
          verbose?: true,
          quiet?: false,
        }, options)
        assert_equal [
          "-vnLee",
          "--count=2",
          "--mode", "fast",
          "--no-quiet",
          "--output", "tmp/out",
          "source.txt",
        ], argv
      end

      def test_forms
        assert_equal({_args: %w[one two]}, parse_args(%w[one two]) {})

        argv = ["--name=Lee=Smith", "--", "--verbose"]
        options = parse_args(argv) do
          _1.str("--name")
          _1.bool("--verbose")
        end
        assert_equal({
          name: "Lee=Smith",
          verbose: false,
          _args: ["--verbose"],
          verbose?: false,
        }, options)

        argv = ["-qvn", "Lee"]
        options = parse_args(argv) do
          _1.bool("-q", "--quiet")
          _1.bool("-v", "--verbose")
          _1.str("-n", "--name")
        end
        assert_equal({
          quiet: true,
          verbose: true,
          name: "Lee",
          _args: [],
          quiet?: true,
          verbose?: true,
        }, options)
      end

      def test_env
        names = %w[
          RUN_KIT_TEST_COUNT RUN_KIT_TEST_FORCE RUN_KIT_TEST_MODE
          RUN_KIT_TEST_NAME RUN_KIT_TEST_OUTPUT RUN_KIT_TEST_RATIO
        ]
        previous = names.to_h { [_1, ENV[_1]] }
        ENV.update({
          "RUN_KIT_TEST_COUNT" => "2",
          "RUN_KIT_TEST_FORCE" => "yes",
          "RUN_KIT_TEST_MODE" => "fast",
          "RUN_KIT_TEST_NAME" => "Lee",
          "RUN_KIT_TEST_OUTPUT" => "tmp/out",
          "RUN_KIT_TEST_RATIO" => "1.5",
        })

        config = Config.new.tap do
          _1.version = "1.2.3"
          _1.bool("--force", env: "RUN_KIT_TEST_FORCE")
          _1.float("--ratio", env: "RUN_KIT_TEST_RATIO")
          _1.int("--count", default: 1, env: "RUN_KIT_TEST_COUNT")
          _1.path("--output", env: "RUN_KIT_TEST_OUTPUT")
          _1.str("--name", required: true, env: "RUN_KIT_TEST_NAME")
          _1.sym("--mode", choices: %i[fast slow], env: "RUN_KIT_TEST_MODE")
        end.tap(&:prepare!)

        assert_equal({
          force: true,
          ratio: 1.5,
          count: 2,
          output: Pathname("tmp/out"),
          name: "Lee",
          mode: :fast,
          _args: [],
          force?: true,
        }, Parser.new(config).parse([]))

        ENV["RUN_KIT_TEST_COUNT"] = "many"
        assert_raises(Error) { Parser.new(config).parse(["--count", "3"]) }

        ENV["RUN_KIT_TEST_COUNT"] = "2"
        options = Parser.new(config).parse(["--no-force", "--count", "3"])
        assert_equal false, options[:force]
        assert_equal false, options[:force?]
        assert_equal 3, options[:count]
      ensure
        previous&.each do |name, value|
          value ? ENV[name] = value : ENV.delete(name)
        end
      end

      def test_global_flags
        config = Config.new.tap do
          _1.bool("-n", "--dry-run")
        end
        child = config.cmd("build") do
          _1.str("-t", "--target", default: "release")
          _1.pos("<file>")
        end
        config.prepare!
        options = Parser.new(child).parse(%w[-ntdebug input])
        assert_equal({
          dry_run: true,
          target: "debug",
          file: "input",
          _args: [],
          dry_run?: true,
        }, options)

        # `--` terminates parsing for both global and command flags.
        options = Parser.new(child).parse(%w[--no-dry-run -- -n])
        assert_equal({
          dry_run: false,
          target: "release",
          file: "-n",
          _args: [],
          dry_run?: false,
        }, options)
      end

      def test_variadic_positionals
        config = Config.new.tap do
          _1.bool("--force")
          _1.pos("<output>")
          _1.pos("<url...>")
        end
        [
          [%w[out one], ["one"], false],
          [%w[out one --force two], %w[one two], true],
          [%w[out -- --force two], %w[--force two], false],
        ].each do |argv, urls, force|
          options = Parser.new(config).parse(argv)
          assert_equal "out", options[:output], argv.inspect
          assert_equal urls, options[:url], argv.inspect
          assert_equal force, options[:force], argv.inspect
          assert_equal [], options[:_args], argv.inspect
        end
        error = assert_raises(Error) { Parser.new(config).parse(["out"]) }
        assert_equal "required argument '<url...>' is missing", error.message

        config = Config.new.tap { _1.pos("<url...>") }
        assert_raises(Error) { Parser.new(config).parse([], infer_help: false) }
        assert_raises(HelpRequested) { Parser.new(config).parse([]) }
      end

      def test_errors
        [
          ["unknown", ["--gub"], ->(o) { o.bool("--good") }],
          ["required", ["extra"], ->(o) { o.str("--name", required: true) }],
          ["missing positional", ["--"], ->(o) { o.pos("<url>") }],
          ["non-boolean negation", ["--no-name"], ->(o) { o.str("--name") }],
          ["invalid smashed", ["-qz"], ->(o) { o.bool("-q") }],
        ].each do |msg, argv, configure|
          assert_raises(Error, msg) { parse_args(argv, &configure) }
        end
      end

      private

      def parse_args(args)
        config = Config.new.tap do
          yield _1
        end
        Parser.new(config).parse(args)
      end
    end
  end
end
