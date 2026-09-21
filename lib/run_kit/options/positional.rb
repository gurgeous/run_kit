#
# A required positional param like `<url>` or `<url...>`.
#

module RunKit
  module Options
    class Positional
      POSITIONAL_RE = /\A<([A-Z]\w*)(\.\.\.)?>\z/i

      attr_reader :help, :meta

      def initialize(meta:, help:)
        @help, @meta = help, meta
        raise ArgumentError, "positional help must be a string" unless help.is_a?(String)
        raise ArgumentError, "positional meta must be a string" unless meta.is_a?(String)
        unless POSITIONAL_RE.match?(meta)
          raise ArgumentError, "invalid positional #{meta.inspect}; wrap the argument name in angle brackets, e.g. o.pos(\"<url>\", \"URL to fetch\")"
        end
      end

      # one-liners
      def key = @key ||= POSITIONAL_RE.match(meta)[1].to_sym
      def variadic? = meta.end_with?("...>")
    end
  end
end
