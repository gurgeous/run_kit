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

      def test_builtin_scan
        previous = ENV["RUN_KIT_TEST_COUNT"]
        ENV["RUN_KIT_TEST_COUNT"] = "invalid"

        [
          [%w[--help build], "Usage: run-kit [options] <command>"],
          [%w[--dry-run build --help], "Usage: run-kit [options] <command>"],
          [%w[--required build --help], "Usage: run-kit [options] <command>"],
          [%w[nonsense build --help], "Usage: run-kit [options] <command>"],
          [%w[build --help], "Usage: run-kit build"],
          [%w[build --unknown -h], "Usage: run-kit build"],
          [%w[build -- --help], "Usage: run-kit build"],
          [%w[build --token --help], "Usage: run-kit build"],
          [%w[--version], "run-kit 1.2.3"],
          [%w[--dry-run build --version], "run-kit 1.2.3"],
          [%w[build -v], "run-kit 1.2.3"],
          [%w[build --version], "run-kit 1.2.3"],
        ].each do |argv, expected|
          status = nil
          main = Main.new.tap do
            _1.config.app_name = "run-kit"
            _1.config.color = false
            _1.config.version = "1.2.3"
            _1.config.int("--count", env: "RUN_KIT_TEST_COUNT")
            _1.config.str("--required", required: true)
            _1.config.cmd("build") { |c| c.str("--token", required: true) }
            _1.config.exit = ->(value) { status = value }
          end
          output, stderr = capture_io { main.parse(argv) }
          assert_equal 0, status, argv.inspect
          assert_equal "", stderr, argv.inspect
          assert_includes output, expected, argv.inspect
        end
      ensure
        previous ? ENV["RUN_KIT_TEST_COUNT"] = previous : ENV.delete("RUN_KIT_TEST_COUNT")
      end

      def test_disabled_version
        main = Main.new.tap do
          _1.config.version = false
          _1.config.bool("-v", "--version")
        end
        options = main.parse(["-v"])
        assert_equal true, options.version
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

      def test_commands
        build = lambda do
          Main.new.tap do |m|
            m.config.app_name = "myapp"
            m.config.bool("-n", "--dry-run")
            m.config.cmd("build", "Build the project") { |c| c.str("--target", default: "release") }
            m.config.cmd("test") { |c| c.bool("--verbose") }
          end
        end

        # bare subcommand uses its defaults
        options = build.call.tap { _1.config.commands[:build].naked = false }.parse(["build"])
        assert_equal({
          dry_run: false,
          target: "release",
          _args: [],
          dry_run?: false,
          command: :build,
        }, options.to_h)

        # global flag + subcommand flag, merged
        options = build.call.parse(["-n", "build", "--target", "debug"])
        assert_equal({
          dry_run: true,
          target: "debug",
          _args: [],
          dry_run?: true,
          command: :build,
        }, options.to_h)

        # subcommand's own help, not the top-level one
        status = nil
        output, = capture_io do
          main = build.call.tap { _1.config.exit = ->(value, *) { status = value } }
          main.parse(["build", "-h"])
        end
        assert_equal 0, status
        assert_includes output, "Usage: myapp build"
        assert_includes output, "--target"

        # bare commands show the hint unless naked is disabled
        output, = capture_io do
          build.call.tap { _1.config.exit = ->(value, *) { status = value } }.parse(["build"])
        end
        assert_equal 0, status
        assert_equal "myapp build: try 'myapp build --help' for more information\n", output

        # child version uses settings assigned after command declaration
        output, = capture_io do
          main = build.call.tap do
            _1.config.version = "1.2.3"
            _1.config.exit = ->(value, *) { status = value }
          end
          main.parse(["build", "--version"])
        end
        assert_equal 0, status
        assert_equal "myapp 1.2.3\n", output

        # top-level help lists commands
        output, = capture_io do
          build.call.tap { _1.config.exit = ->(*) {} }.parse(["--help"])
        end
        assert_includes output, "Commands:"
        assert_includes output, "build  Build the project"

        # unknown command
        status = nil
        _, stderr = capture_io do
          main = build.call.tap { _1.config.exit = ->(value, *) { status = value } }
          main.parse(["bogus"])
        end
        assert_equal 1, status
        assert_includes stderr, "unknown command 'bogus'"

        # subcommand errors use the subcommand's context
        _, stderr = capture_io do
          build.call.tap { _1.config.exit = ->(*) {} }.parse(["build", "--wat"])
        end
        assert_includes stderr, "myapp build: unexpected argument '--wat' found"
        assert_includes stderr, "myapp build: try 'myapp build --help'"
      end

      def test_command_key
        ["--command", "<command>"].each do |declaration|
          main = Main.new.tap do |m|
            m.config.cmd("run") do |c|
              declaration.start_with?("--") ? c.str(declaration) : c.pos(declaration)
            end
          end
          argv = declaration.start_with?("--") ? %w[run --command echo] : %w[run echo]
          options = main.parse(argv)
          assert_equal :run, options.command, declaration
        end
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
