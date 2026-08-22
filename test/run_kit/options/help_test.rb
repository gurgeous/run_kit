require "run_kit"

module RunKit
  module Options
    class HelpTest < Minitest::Test
      def test_basic
        config = base_config.tap do
          _1.version = "1.2.3"
          _1.sep("Connection:")
          _1.str("-H", "--host <name>", "hostname")
          _1.int("-p", "--port", "port")
          _1.sep
          _1.bool("--quiet", "suppress output")
          _1.pos("<url>", "URL")
        end.tap(&:prepare!)

        exp = <<~TEXT
          Usage: run-kit [options] <url>

          Connection:
            -H, --host <name>  hostname
            -p, --port <int>   port

            --quiet            suppress output
            -h, --help         Show this message
            -v, --version      Show version
        TEXT
        assert_equal exp, Help.new(config).to_s
      end

      def test_width
        config = Config.new

        assert_equal 60, Help.new(config, 1).width
        assert_equal 80, Help.new(config, 80).width
        assert_equal 100, Help.new(config, 1_000).width
      end

      def test_custom_text
        banner = base_config.tap do
          _1.banner = "run-kit custom usage"
          _1.bool("--verbose", "verbose output")
        end.tap(&:prepare!)

        assert_match(/\Arun-kit custom usage\n  --verbose/, Help.new(banner).to_s)

        custom = base_config.tap { _1.help = "Custom help\n" }
        assert_equal "Custom help\n", Help.new(custom).to_s
      end

      def test_wrap
        config = base_config.tap do
          _1.str("--long", "one two three four five six seven eight nine ten")
        end.tap(&:prepare!)

        assert_match(
          /--long <str>  one two three four five six seven eight nine\n\s+ten/,
          Help.new(config, 60).to_s
        )
      end

      def test_color
        config = base_config.tap do
          _1.color = true
          _1.sep("Options:")
          _1.str("--host <name>", "hostname")
        end.tap(&:prepare!)

        assert_match(/\e\[1;32m--host\e\[0m/, Help.new(config).to_s)
        assert_match(/\e\[1;33m<name>\e\[0m/, Help.new(config).to_s)
      end

      private

      def base_config
        Config.new.tap do
          _1.app_name = "run-kit"
          _1.color = false
        end
      end
    end
  end
end
