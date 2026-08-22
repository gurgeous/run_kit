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
