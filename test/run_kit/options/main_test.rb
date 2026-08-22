require "run_kit"

module RunKit
  module Options
    class MainTest < Minitest::Test
      def test_basic
        main = Main.new.tap do
          _1.config.bool("-v", "--verbose")
          _1.config.bool("--color", default: true)
          _1.config.str("--name", default: "default")
          _1.config.positional("<url>")
        end
        options = main.parse([
          "-v", "--no-color", "--name", "Lee",
          "https://example.com", "one", "two",
        ])

        assert_equal({
          color: false,
          name: "Lee",
          url: "https://example.com",
          verbose: true,
          _args: %w[one two],
          verbose?: true,
          color?: false,
        }, options.to_h)
        assert_true options.is_a?(Data)
        assert_true options.verbose?
        assert_false options.color?
        assert_equal "Lee", options.name
        assert_raises(NoMethodError) { options.name = "Pat" }
      end

      def test_early_exits
        # help
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.config.app_name = "run-kit"
            _1.config.exit = ->(value) { status = value }
          end.parse(["--help"])
        end
        assert_equal 0, status
        assert_includes output, "Usage: run-kit"

        # version
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.config.app_name = "run-kit"
            _1.config.version = "1.2.3"
            _1.config.exit = ->(value) { status = value }
          end.parse(["--version"])
        end
        assert_equal 0, status
        assert_includes output, "run-kit 1.2.3"

        # naked
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.config.app_name = "run-kit"
            _1.config.exit = ->(value) { status = value }
          end.parse([])
        end
        assert_equal 0, status
        assert_includes output, "try 'run-kit --help'"
      end

      def test_error
        status = nil
        _, stderr = capture_io do
          cli = Main.new.tap do
            _1.config.app_name = "run-kit"
            _1.config.naked = false
            _1.config.exit = ->(value, msg) { status = value }
          end
          cli.parse(["--unknown"])
        end
        assert_equal 1, status
        assert_includes stderr, "try 'run-kit --help'"
      end

      # Options.parse
      def test_options_parse
        options = Options.parse(["-vn8", "--mode=fast", "https://example.com"]) do
          _1.bool "-v", "--verbose"
          _1.int "-n", "--count <n>"
          _1.str "-m", "--mode <mode>", choices: %w[fast slow]
          _1.positional "<url>"
        end

        assert_equal({
          verbose: true,
          count: 8,
          mode: "fast",
          url: "https://example.com",
          _args: [],
          verbose?: true,
        }, options.to_h)
      end
    end
  end
end
