#
# A required positional param like `<url>`.
#

module RunKit
  module Options
    class Positional
      POSITIONAL_RE = /\A<([A-Z]\w*)>\z/i

      attr_reader :help, :meta

      def initialize(meta:, help:)
        @help, @meta = help, meta
        raise ArgumentError, "positional help must be a string" unless help.is_a?(String)
        raise ArgumentError, "positional meta must be a string" unless meta.is_a?(String)
        raise ArgumentError, "positional must use <meta>" unless POSITIONAL_RE.match?(meta)
      end

      # one-liners
      def key = @key ||= POSITIONAL_RE.match(meta)[1].to_sym
    end
  end
end
