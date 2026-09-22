require "run_kit"

module RunKit
  module Options
    class MainTest < Minitest::Test
      def test_basic
        main = Main.new.tap do
          _1.root.bool("-v", "--verbose")
          _1.root.bool("--color")
          _1.root.str("--name", default: "default")
          _1.root.positional("<url>")
        end
        options = main.parse([
          "-v", "--name", "Lee",
          "https://example.com",
        ])

        assert_equal({
          color: false,
          name: "Lee",
          url: "https://example.com",
          verbose: true,
          _args: [],
          verbose?: true,
          color?: false,
        }, options.to_h)
        assert_true options.verbose?
        assert_false options.color?
        assert_equal "Lee", options.name
      end

      def test_early_exits
        # help
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.root.app_name = "run-kit"
            _1.root.exit = ->(value) { status = value }
          end.parse(["--help"])
        end
        assert_equal 0, status
        assert_includes output, "Usage: run-kit"

        # version
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.root.app_name = "run-kit"
            _1.root.version = "1.2.3"
            _1.root.exit = ->(value) { status = value }
          end.parse(["--version"])
        end
        assert_equal 0, status
        assert_includes output, "run-kit 1.2.3"

        # missing required input on a bare invocation
        status = nil
        output, = capture_io do
          Main.new.tap do
            _1.root.app_name = "run-kit"
            _1.root.pos("<url>")
            _1.root.exit = ->(value) { status = value }
          end.parse([])
        end
        assert_equal 0, status
        assert_includes output, "Usage: run-kit [options]"
        assert_includes output, "--help"
      end

      def test_inferred_help
        previous = ENV["RUN_KIT_TEST_FORCE"]
        [
          [nil, [], 0],
          ["false", [], nil],
          ["invalid", [], 2],
          [nil, %w[--no-force], 2],
          [nil, %w[--other], 2],
        ].each do |env, argv, expected_status|
          env ? ENV["RUN_KIT_TEST_FORCE"] = env : ENV.delete("RUN_KIT_TEST_FORCE")
          %i[root explicit default].each do |mode|
            status = options = nil
            main = Main.new.tap do |m|
              m.root.exit = ->(value, *) { status = value }
              config = (mode == :root) ? m.root : m.root.cmd("build", default: mode == :default)
              config.bool("--force", required: true, env: "RUN_KIT_TEST_FORCE")
              config.bool("--other")
            end
            output, stderr = capture_io { options = main.parse((mode == :explicit) ? ["build", *argv] : argv) }
            msg = [env, argv, mode].inspect
            expected = (mode == :explicit && expected_status == 0) ? 2 : expected_status
            assert_equal expected, status, msg
            if expected == 0
              assert_includes output, "Usage:", msg
              assert_equal "", stderr, msg
            elsif expected == 2
              assert_equal "", output, msg
              assert_includes stderr, "try '", msg
            else
              assert_equal false, options.force?, msg
              assert_equal "", output, msg
              assert_equal "", stderr, msg
            end
          end
        end

        [[], ["example.com"]].each do |argv|
          status = nil
          main = Main.new.tap do
            _1.root.pos("<url>")
            _1.root.exit = ->(value, *) { status = value }
          end
          capture_io { main.parse(argv) }
          assert_equal(argv.empty? ? 0 : nil, status)
        end

        assert_equal({_args: []}, Main.new.parse([]).to_h)
      ensure
        previous ? ENV["RUN_KIT_TEST_FORCE"] = previous : ENV.delete("RUN_KIT_TEST_FORCE")
      end

      def test_bare_commands
        [
          [nil, [], nil, "Usage: app <command> [options]"],
          [nil, ["standalone"], "standalone", nil],
          [nil, ["sick"], nil, nil],
          ["standalone", [], "standalone", nil],
          ["sick", [], nil, "Usage: app <command> [options]"],
          ["sick", ["sick"], nil, nil],
        ].each do |default, argv, command, help|
          status = options = nil
          main = Main.new.tap do
            _1.root.app_name = "app"
            _1.root.color = false
            _1.root.exit = ->(value) { status = value }
            _1.root.cmd("standalone", default: default == "standalone")
            _1.root.cmd("sick", default: default == "sick") { |c| c.pos("<url>") }
          end
          output, stderr = capture_io { options = main.parse(argv) }
          msg = [default, argv].inspect
          if help
            assert_equal "", stderr, msg
            assert_equal 0, status, msg
            assert_includes output, help, msg
          elsif command
            assert_equal "", stderr, msg
            assert_nil status, msg
            assert_equal command, options.command, msg
            assert_equal "", output, msg
          else
            assert_equal 2, status, msg
            assert_equal "", output, msg
            assert_includes stderr, "app sick: required argument '<url>' is missing", msg
          end
        end
      end

      def test_builtin_scan
        previous = ENV["RUN_KIT_TEST_COUNT"]
        ENV["RUN_KIT_TEST_COUNT"] = "invalid"

        [
          [%w[--help build], "Usage: run-kit <command> [options]"],
          [%w[--dry-run build --help], "Usage: run-kit <command> [options]"],
          [%w[--required build --help], "Usage: run-kit <command> [options]"],
          [%w[nonsense build --help], "Usage: run-kit <command> [options]"],
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
            _1.root.app_name = "run-kit"
            _1.root.color = false
            _1.root.version = "1.2.3"
            _1.root.int("--count", env: "RUN_KIT_TEST_COUNT")
            _1.root.str("--required", required: true)
            _1.root.cmd("build") { |c| c.str("--token", required: true) }
            _1.root.exit = ->(value) { status = value }
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
          _1.root.version = false
          _1.root.bool("-v", "--version")
        end
        options = main.parse(["-v"])
        assert_equal true, options.version
      end

      def test_error
        status = nil
        _, stderr = capture_io do
          cli = Main.new.tap do
            _1.root.app_name = "run-kit"
            _1.root.exit = ->(value, msg) { status = value }
          end
          cli.parse(["--unknown"])
        end
        assert_equal 2, status
        assert_includes stderr, "try 'run-kit --help'"
      end

      def test_commands
        build = lambda do
          Main.new.tap do |m|
            m.root.app_name = "myapp"
            m.root.bool("-n", "--dry-run")
            m.root.cmd("build", "Build the project") { |c| c.str("--target", default: "release") }
            m.root.cmd("test") { |c| c.bool("--verbose") }
          end
        end

        # bare subcommand uses its defaults
        options = build.call.parse(["build"])
        assert_equal({
          dry_run: false,
          target: "release",
          _args: [],
          dry_run?: false,
          command: "build",
        }, options.to_h)

        # global and subcommand flags follow the command
        options = build.call.parse(["build", "-n", "--target", "debug"])
        assert_equal({
          dry_run: true,
          target: "debug",
          _args: [],
          dry_run?: true,
          command: "build",
        }, options.to_h)

        # subcommand's own help, not the top-level one
        status = nil
        output, = capture_io do
          main = build.call.tap { _1.root.exit = ->(value, *) { status = value } }
          main.parse(["build", "-h"])
        end
        assert_equal 0, status
        assert_includes output, "Usage: myapp build"
        assert_includes output, "--target"
        assert_includes output, "Other options:"
        assert_includes output, "--dry-run"

        # explicitly selected commands report missing requirements
        output, stderr = capture_io do
          build.call.tap do
            _1.root.commands["build"].pos("<path>")
            _1.root.exit = ->(value, *) { status = value }
          end.parse(["build"])
        end
        assert_equal 2, status
        assert_equal "", output
        assert_includes stderr, "myapp build: required argument '<path>' is missing"

        # subcommand --version prints the root version
        output, = capture_io do
          main = build.call.tap do
            _1.root.version = "1.2.3"
            _1.root.exit = ->(value, *) { status = value }
          end
          main.parse(["build", "--version"])
        end
        assert_equal 0, status
        assert_equal "myapp 1.2.3\n", output

        # top-level help lists commands
        output, = capture_io do
          build.call.tap { _1.root.exit = ->(*) {} }.parse(["--help"])
        end
        assert_includes output, "Commands:"
        assert_includes output, "build  Build the project"

        # unknown command
        status = nil
        _, stderr = capture_io do
          main = build.call.tap { _1.root.exit = ->(value, *) { status = value } }
          main.parse(["bogus"])
        end
        assert_equal 2, status
        assert_includes stderr, "unknown command 'bogus'"

        # subcommand errors use the subcommand's context
        _, stderr = capture_io do
          build.call.tap { _1.root.exit = ->(*) {} }.parse(["build", "--wat"])
        end
        assert_includes stderr, "myapp build: unexpected argument '--wat' found"
        assert_includes stderr, "myapp build: try 'myapp build --help'"
      end

      def test_command_first
        main = Main.new.tap do
          _1.root.exit = ->(*) {}
          _1.root.bool("-f", "--force")
          _1.root.int("-n", "--count")
          _1.root.cmd("build")
        end
        %w[--force -f --count=2 -n2].each do |flag|
          _, stderr = capture_io { assert_nil main.parse([flag, "build"]) }
          assert_includes stderr, "global options must follow the command"
        end
      end

      def test_extra_positionals
        %i[root explicit default].each do |mode|
          main = Main.new.tap do
            _1.root.exit = ->(*) {}
            config = (mode == :root) ? _1.root : _1.root.cmd("fetch", default: mode == :default)
            config.pos("<url>")
          end
          [%w[example.com extra], %w[example.com -- extra]].each do |args|
            argv = (mode == :explicit) ? ["fetch", *args] : args
            _, stderr = capture_io { assert_nil main.parse(argv) }
            assert_includes stderr, "unexpected argument 'extra' found", "#{mode}: #{argv.inspect}"
          end
        end
      end

      def test_command_env
        previous = ENV["RUN_KIT_TEST_COUNT"]
        ENV["RUN_KIT_TEST_COUNT"] = "2"
        main = Main.new.tap do
          _1.root.exit = ->(*) {}
          _1.root.int("--count", required: true, env: "RUN_KIT_TEST_COUNT")
          _1.root.cmd("build") { |c| c.int("--size", env: "RUN_KIT_TEST_COUNT") }
        end
        options = main.parse(%w[build --size 3])
        assert_equal 2, options.count
        assert_equal 3, options.size

        ENV.delete("RUN_KIT_TEST_COUNT")
        _, stderr = capture_io { assert_nil main.parse(%w[build]) }
        assert_includes stderr, "build: required option '--count' is missing"

        ENV["RUN_KIT_TEST_COUNT"] = "invalid"
        _, stderr = capture_io { assert_nil main.parse(%w[build --count 3]) }
        assert_includes stderr, "build:"
        output, stderr = capture_io { main.parse(%w[build --help]) }
        assert_includes output, "--count"
        assert_equal "", stderr
      ensure
        previous ? ENV["RUN_KIT_TEST_COUNT"] = previous : ENV.delete("RUN_KIT_TEST_COUNT")
      end

      def test_parse_context
        main = Main.new.tap do
          _1.root.exit = ->(*) {}
          _1.root.cmd(:build)
        end
        main.parse(["build"])
        assert_equal main.root.commands["build"], main.ctx

        capture_io { main.parse(["--help"]) }
        assert_equal main.root, main.ctx
      end

      def test_validation
        [nil, false, "ignored"].each do |value|
          seen = []
          main = Main.new.tap do
            _1.root.int("--count", default: 1)
            _1.root.validate = lambda do |options|
              seen << options
              value
            end
          end
          options = main.parse(%w[--count 2])
          assert_equal 2, options.count
          assert_equal [options], seen
        end

        seen = []
        main = Main.new.tap do |m|
          m.root.bool("--force")
          m.root.validate = ->(options) { seen << [:root, options] }
          m.root.cmd("build") do |c|
            c.int("--count", default: 1)
            c.validate = ->(options) { seen << [:child, options] }
          end
        end
        options = main.parse(%w[build --force --count 2])
        assert_equal [[:root, options], [:child, options]], seen
        assert_equal true, options.force?
        assert_equal 2, options.count
        assert_equal "build", options.command
      end

      def test_validation_errors
        %i[root child].each do |failing|
          seen = []
          status = message = nil
          main = Main.new.tap do |m|
            m.root.app_name = "myapp"
            m.root.exit = ->(code, error) { status, message = code, error }
            child = m.root.cmd("build")
            {root: m.root, child:}.each do |name, context|
              context.validate = lambda do |_options|
                seen << name
                raise "invalid combination" if name == failing
              end
            end
          end
          _, stderr = capture_io { assert_nil main.parse(["build"]) }
          app = (failing == :root) ? "myapp" : "myapp build"
          assert_equal "#{app}: invalid combination\n#{app}: try '#{app} --help' for more information\n", stderr
          assert_equal 2, status
          assert_equal "invalid combination", message
          assert_equal((failing == :root) ? [:root] : %i[root child], seen)
        end

        main = Main.new.tap do
          _1.root.validate = ->(options) { options.missing_method }
        end
        assert_raises(NoMethodError) { main.parse([]) }
      end

      def test_validation_skipped
        [[], %w[--help], %w[--version], %w[--unknown], %w[build], %w[build --help], %w[build --unknown]].each do |argv|
          seen = []
          main = Main.new.tap do
            _1.root.version = "1.2.3"
            _1.root.exit = ->(*) {}
            _1.root.validate = ->(options) { seen << options }
            _1.root.cmd("build") do |c|
              c.pos("<url>")
              c.validate = ->(options) { seen << options }
            end
          end
          capture_io { main.parse(argv) }
          assert_equal [], seen, argv.inspect
        end
      end

      def test_default_command
        [
          [%w[example.com], "fetch", "example.com", 1, false],
          [%w[stats], "fetch", "stats", 1, false],
          [%w[fetch example.com], "fetch", "example.com", 1, false],
          [%w[--count=2 example.com], "fetch", "example.com", 2, false],
          [%w[-n2 example.com], "fetch", "example.com", 2, false],
          [%w[--dry-run --count 2 example.com], "fetch", "example.com", 2, true],
          [%w[status --dry-run], "status", nil, nil, true],
          [%w[--dry-run status], "fetch", "status", 1, true],
        ].each do |argv, command, url, count, dry_run|
          options = Options.parse(argv) do
            _1.bool("--dry-run")
            _1.cmd("fetch", default: true) do |c|
              c.pos("<url>")
              c.int("-n", "--count", default: 1)
            end
            _1.cmd("status")
          end
          assert_equal command, options.command, argv.inspect
          assert_equal dry_run, options.dry_run, argv.inspect
          if command == "fetch"
            assert_equal url, options.url, argv.inspect
            assert_equal count, options.count, argv.inspect
            assert_equal [], options._args, argv.inspect
          end
        end

        options = Options.parse([]) { _1.cmd("status", default: true) }
        assert_equal "status", options.command
      end

      def test_default_command_help_and_errors
        main = Main.new.tap do
          _1.root.app_name = "app"
          _1.root.color = false
          _1.root.exit = ->(*) {}
          _1.root.cmd("fetch", "Fetch a URL", default: true) { |c| c.pos("<url>") }
          _1.root.cmd("status")
        end

        output, = capture_io { main.parse(["--help"]) }
        assert_includes output, "Usage: app <command> [options]"
        assert_includes output, "fetch (default)  Fetch a URL"

        output, = capture_io { main.parse([]) }
        assert_includes output, "Usage: app <command> [options]"

        status = nil
        main.root.exit = ->(value) { status = value }
        _, stderr = capture_io { main.parse(%w[--unknown example.com]) }
        assert_equal 2, status
        assert_includes stderr, "app fetch: unexpected argument '--unknown'"
      end

      def test_command_key
        ["--command", "<command>"].each do |declaration|
          main = Main.new.tap do |m|
            m.root.cmd("run") do |c|
              declaration.start_with?("--") ? c.str(declaration) : c.pos(declaration)
            end
          end
          argv = declaration.start_with?("--") ? %w[run --command echo] : %w[run echo]
          options = main.parse(argv)
          assert_equal "run", options.command, declaration
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
