require "run_kit"

module RunKit
  module Options
    class ConfigTest < Minitest::Test
      def test_basic
        config = Config.new.tap do
          _1.app_name = "fetch"
          _1.banner = "Fetch a URL"
          _1.color = false
          _1.version = "1.2.3"
          _1.sep("Options:")
          _1.bool("-q", "--quiet", "Suppress output")
          _1.float("--timeout", default: 1.5)
          _1.int("-r", "--retries <count>", "Retry count", default: 2)
          _1.path("-o", "--output", required: true)
          _1.str("--format", choices: %w[json text])
          _1.sym("--mode", default: :fast, choices: %i[fast safe])
          _1.pos("<url>", "URL to fetch")
        end.tap(&:prepare!)

        assert_equal true, config.neurotic?

        # flags
        assert_equal({
          format: :str,
          help: :bool,
          mode: :sym,
          output: :path,
          quiet: :bool,
          retries: :int,
          timeout: :float,
          version: :bool,
        }, config.flags.to_h { [_1.key, _1.kind] })
        assert_equal({quiet: false, timeout: 1.5, retries: 2, format: nil, mode: :fast}, config.defaults)
        assert_equal [:output], config.required.map(&:key)

        # pos/sep
        assert_equal [[:url, "<url>", "URL to fetch"]], config.positionals.map { [_1.key, _1.meta, _1.help] }
        assert_equal [[0, "Options:"]], config.separators

        # lookups
        assert_equal config.flag(:retries), config.flag("--retries")
        assert_equal ["-r", "--retries"], config.flag(:retries).switches
        assert_equal "count", config.flag(:retries).meta
        assert_equal "Retry count", config.flag(:retries).help

        # builtins
        assert_equal config.flag("--help"), config.help_flag
        assert_equal config.flag("--version"), config.version_flag
      end

      def test_reserved_builtins
        %w[-h --help -v --version].each do |switch|
          config = Config.new.tap do
            _1.version = "1.2.3"
            _1.bool(switch)
          end
          assert_raises(ArgumentError, switch) { config.prepare! }
        end
      end

      def test_invalid_declarations
        config = Config.new.tap do
          _1.str("-n", "--name")
          _1.pos("<url>")
        end

        [
          ["dup key", -> { config.str("--name") }],
          ["dup switch", -> { config.bool("-d", "-d") }],
          ["dup pos", -> { config.pos("<url>") }],
          ["reserved", -> { config.str("--_args") }],
          ["pos collision", -> { config.str("--url") }],
        ].each do |msg, proc|
          assert_raises(ArgumentError, msg, &proc)
        end
      end

      def test_commands
        config = Config.new.tap do |o|
          o.bool("-n", "--dry-run")
          o.cmd("build", "Build the project") { |c| c.str("--target", default: "release") }
          o.cmd("test") { |c| c.bool("--verbose") }
          o.app_name = "myapp"
          o.color = false
          o.exit = ->(*) {}
          o.version = "1.2.3"
        end.tap(&:prepare!)

        assert_equal %w[build test], config.commands.keys
        build = config.commands["build"]
        assert_nil config.root
        assert_same config, build.root
        assert_equal "myapp build", build.full_name
        assert_equal "Build the project", build.desc
        assert_equal false, build.neurotic?
        assert_equal false, build.color
        assert_equal config.exit, build.exit
        assert_equal "1.2.3", build.version
        assert_nil config.commands["test"].desc
      end

      def test_full_name
        named = Config.new(name: :custom)
        assert_equal "custom", named.name
        assert_equal "custom", named.full_name

        config = Config.new
        assert_equal File.basename($PROGRAM_NAME), config.name
        child = config.cmd(:build)
        assert_equal "build", child.name
        assert_equal "#{config.name} build", child.full_name

        config.app_name = :myapp
        config.prepare!
        assert_equal "myapp build", child.full_name

        config.name = :renamed
        assert_equal "renamed", config.name
        assert_equal "renamed build", child.full_name
      end

      def test_invalid_commands
        assert_raises(ArgumentError) do
          Config.new.tap do
            _1.cmd("fetch", default: true)
            _1.cmd("build", default: true)
          end
        end

        assert_raises(ArgumentError) do
          Config.new.tap do |o|
            o.cmd("build") {}
            o.cmd(:build) {}
          end
        end

        assert_raises(ArgumentError) do
          Config.new.cmd("outer") { _1.cmd("inner") }
        end
      end

      def test_command_collisions
        [
          ->(c) { c.bool("-n", "--other") },
          ->(c) { c.bool("--dry-run") },
          ->(c) { c.bool("--dry_run") },
          ->(c) { c.pos("<dry_run>") },
        ].each do |configure|
          config = Config.new.tap do
            _1.cmd("build", &configure)
            _1.bool("-n", "--dry-run")
          end
          assert_raises(ArgumentError) { config.prepare! }
        end

        # Siblings can reuse flags; generated builtins are shared.
        config = Config.new.tap do
          _1.version = "1.2.3"
          _1.cmd("build") { |c| c.bool("-n", "--dry-run") }
          _1.cmd("test") { |c| c.bool("-n", "--dry-run") }
        end
        config.prepare!
        assert_equal %w[build test], config.commands.keys
      end

      def test_root_positionals_with_commands
        [true, false].each do |pos_first|
          config = Config.new.tap do
            _1.pos("<url>") if pos_first
            _1.cmd("build")
            _1.pos("<url>") unless pos_first
          end
          assert_raises(ArgumentError) { config.prepare! }
        end
      end
    end
  end
end
