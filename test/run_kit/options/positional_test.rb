require "run_kit"

module RunKit
  module Options
    class PositionalTest < Minitest::Test
      def test_basic
        positional = Positional.new(meta: "<url>", help: "URL")

        assert_equal "<url>", positional.meta
        assert_equal "URL", positional.help
        assert_equal :url, positional.key

        variadic = Positional.new(meta: "<url...>", help: "URLs")
        assert_equal :url, variadic.key
        assert_equal true, variadic.variadic?
        assert_equal false, positional.variadic?

        [
          {meta: "<url>", help: nil},
          {meta: nil, help: ""},
          {meta: "url", help: ""},
          {meta: "<url..>", help: ""},
        ].each do |kwargs|
          assert_raises(ArgumentError, kwargs.inspect) { Positional.new(**kwargs) }
        end
      end

      def test_invalid_syntax_message
        error = assert_raises(ArgumentError) { Positional.new(meta: "url", help: "") }
        assert_equal 'invalid positional "url"; wrap the argument name in angle brackets, e.g. o.pos("<url>", "URL to fetch")', error.message
      end
    end
  end
end
