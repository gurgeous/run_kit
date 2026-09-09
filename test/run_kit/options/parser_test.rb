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
          "extra.txt",
        ]
        config = Config.new.tap do
          _1.naked = false
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
          _args: ["extra.txt"],
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
          "extra.txt",
        ], argv
      end

      def test_forms
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

        assert_raises(NakedRequested) { Parser.new(config).parse([]) }
        config.naked = false

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
        assert_raises(HelpRequested) { Parser.new(config).parse(["--help"]) }
        assert_raises(VersionRequested) { Parser.new(config).parse(["--version"]) }

        options = Parser.new(config).parse(["--no-force", "--count", "3"])
        assert_equal false, options[:force]
        assert_equal false, options[:force?]
        assert_equal 3, options[:count]
      ensure
        previous&.each do |name, value|
          value ? ENV[name] = value : ENV.delete(name)
        end
      end

      def test_errors
        [
          ["unknown", ["--gub"], ->(o) { o.bool("--good") }],
          ["required", [], ->(o) { o.str("--name", required: true) }],
          ["missing positional", [], ->(o) { o.pos("<url>") }],
          ["non-boolean negation", ["--no-name"], ->(o) { o.str("--name") }],
          ["invalid smashed", ["-qz"], ->(o) { o.bool("-q") }],
        ].each do |msg, argv, configure|
          assert_raises(Error, msg) { parse_args(argv, &configure) }
        end
      end

      private

      def parse_args(args)
        config = Config.new.tap do
          _1.naked = false
          yield _1
        end
        Parser.new(config).parse(args)
      end
    end
  end
end
