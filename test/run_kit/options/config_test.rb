require "run_kit"

module RunKit
  module Options
    class ConfigTest < Minitest::Test
      def test_basic
        config = Config.new.tap do
          _1.app_name = "fetch"
          _1.banner = "Fetch a URL"
          _1.color = false
          _1.naked = false
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

        # misc
        assert_equal "fetch", config.app_name
        assert_equal "Fetch a URL", config.banner
        assert_false config.color
        assert_false config.naked?
        assert_equal "1.2.3", config.version

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

      def test_override_builtins
        config = Config.new.tap do
          _1.bool("-h", "--help")
          _1.bool("-v", "--version")
          _1.version = "1.2.3"
        end.tap(&:prepare!)
        assert_nil config.help_flag
        assert_nil config.version_flag

        config = Config.new.tap do
          _1.bool("-h")
        end.tap(&:prepare!)
        assert_equal ["--help"], config.help_flag.switches
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
    end
  end
end
