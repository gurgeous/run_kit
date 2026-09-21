require "run_kit"

module RunKit
  module Options
    class FlagTest < Minitest::Test
      def test_error_context
        error = assert_raises(ArgumentError) do
          Config.new.int("-c", "--count <number>", default: "many")
        end
        assert_includes error.message, "--count"
      end

      def test_basic
        flag = Flag.new(
          :sym,
          ["-m", "--http-mode <mode>", "Request mode"],
          default: :fast,
          choices: %i[fast safe]
        )

        assert_equal :sym, flag.kind
        assert_equal ["-m", "--http-mode"], flag.switches
        assert_equal "mode", flag.meta
        assert_equal "Request mode", flag.help
        assert_equal :fast, flag.default
        assert_equal %i[fast safe], flag.choices
        assert_equal nil, flag.env
        assert_false flag.required?
        assert_equal :http_mode, flag.key
        assert_equal :safe, flag.parse("--http-mode", "safe")

        flag = Flag.new(:bool, ["-v", "--verbose", "Verbose output"])
        assert_equal false, flag.default
        assert_equal true, flag.parse("--verbose", nil)
      end

      def test_env
        flag = Flag.new(:str, ["--http-mode"], env: true)
        assert_equal "HTTP_MODE", flag.env

        [
          [%w[1 TRUE Yes on], true],
          [[""], false],
          [%w[0 FALSE No off], false],
        ].each do |values, exp|
          values.each do |param|
            assert_equal exp, Flag.new(:bool, ["--value"], env: "VALUE").parse_env(param), param
          end
        end

        [
          [Flag.new(:float, ["--value"], env: "VALUE"), "1.5", 1.5],
          [Flag.new(:int, ["--value"], env: "VALUE"), "-2", -2],
          [Flag.new(:path, ["--value"], env: "VALUE"), "tmp/out", Pathname("tmp/out")],
          [Flag.new(:str, ["--value"], env: "VALUE"), "Lee", "Lee"],
          [Flag.new(:sym, ["--value"], choices: %i[fast slow], env: "VALUE"), "fast", :fast],
        ].each do |env_flag, param, exp|
          assert_equal exp, env_flag.parse_env(param), [env_flag.kind, param].inspect
        end

        error = assert_raises(Error) { Flag.new(:bool, ["--force"], env: true).parse_env("maybe") }
        assert_equal "invalid value 'maybe' for environment variable 'FORCE'", error.message
        assert_raises(Error) { Flag.new(:int, ["--count"], env: true).parse_env("many") }
        assert_raises(Error) do
          Flag.new(:sym, ["--mode"], choices: %i[fast slow], env: true).parse_env("other")
        end
      end

      def test_good
        [
          [:float, "1.5", nil, 1.5],
          [:int, "-2", nil, -2],
          [:path, "tmp/out", nil, Pathname("tmp/out")],
          [:str, "Lee", nil, "Lee"],
          [:sym, "fast", nil, :fast],
          [:sym, "fast", %i[slow fast], :fast],
        ].each do |kind, param, choices, exp|
          flag = Flag.new(kind, ["--value"], choices:)
          assert_equal exp, flag.parse("--value", param), [kind, param, choices].inspect
        end

        [
          [Flag.new(:bool, ["--quiet"]), "true"],
          [Flag.new(:str, ["--name"]), nil],
          [Flag.new(:int, ["--count"]), "many"],
          [Flag.new(:sym, ["--mode"], choices: %i[fast auto]), "slow"],
        ].each do |flag, param|
          assert_raises(Error, [flag.kind, param].inspect) { flag.parse("--value", param) }
        end
      end

      def test_bad
        [
          ["kind", -> { Flag.new(:unknown, ["--unknown"]) }],
          ["switch missing", -> { Flag.new(:str, []) }],
          ["undashed name", -> { Config.new.str("something") }],
          ["undashed name with env", -> { Config.new.str("something", env: true) }],
          ["switch type", -> { Flag.new(:str, [:name]) }],
          ["switch format", -> { Flag.new(:str, ["-word"]) }],
          ["switch duplicate", -> { Flag.new(:str, ["-n", "-n"]) }],
          ["bool meta", -> { Flag.new(:bool, ["--quiet <bool>"]) }],
          ["required type", -> { Flag.new(:str, ["--name"], required: nil) }],
          ["required default", -> { Flag.new(:str, ["--name"], required: true, default: "Lee") }],
          ["default type", -> { Flag.new(:int, ["--count"], default: "1") }],
          ["choices type", -> { Flag.new(:str, ["--name"], choices: "Lee") }],
          ["choices empty", -> { Flag.new(:str, ["--name"], choices: []) }],
          ["choice type", -> { Flag.new(:sym, ["--mode"], choices: ["fast"]) }],
          ["env type", -> { Flag.new(:str, ["--name"], env: false) }],
        ].each do |msg, action|
          assert_raises(ArgumentError, msg, &action)
        end
      end
    end
  end
end
