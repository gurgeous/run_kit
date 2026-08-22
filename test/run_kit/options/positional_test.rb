require "run_kit"

module RunKit
  module Options
    class PositionalTest < Minitest::Test
      def test_basic
        positional = Positional.new(meta: "<url>", help: "URL")

        assert_equal "<url>", positional.meta
        assert_equal "URL", positional.help
        assert_equal :url, positional.key

        [
          {meta: "<url>", help: nil},
          {meta: nil, help: ""},
          {meta: "url", help: ""},
        ].each do |kwargs|
          assert_raises(ArgumentError, kwargs.inspect) { Positional.new(**kwargs) }
        end
      end
    end
  end
end
