module RunKit
  module CoreExt
    module Enumerable
      def tally_sorted
        keyfn = case find { _1 }
        when ::String then -> { _1&.downcase || "\uffff" }
        when ::Numeric then -> { _1 || Float::MAX }
        when ::Array then -> { _1 || [] }
        when TrueClass, FalseClass then -> { (_1 != nil) ? (_1 ? 0 : 1) : Float::MAX }
        end

        unsorted = tally
        begin
          unsorted.sort_by { [-_2, keyfn&.call(_1)] }
        rescue ArgumentError, NoMethodError
          keyfn = nil # mixed types, don't sort on key
          retry
        end.to_h
      end

      def variance(sample: true)
        n = length
        return if (sample && n < 2) || (!sample && n.zero?)
        mu = mean
        denom = sample ? (n - 1) : n
        sum(0.0) { (_1 - mu)**2 } / denom
      end

      # one-liners
      def mean = empty? ? nil : sum(0.0) / length
      def stddev(sample: true) = variance(sample:)&.sqrt
    end

    # each.with_progresbar
    module Enumerator
      def with_progressbar(options = {}, &block)
        defaults = {
          format: "%t: %j%% %B #{RunKit::Term.paint_ansi("%c/%u %e", RunKit::Term.ansi256_fg(242))}",
          progress_mark: RunKit::Term.paint_ansi("━", RunKit::Term.ansi256_fg(46)),
          remainder_mark: RunKit::Term.paint_ansi("━", RunKit::Term.ansi256_fg(237)),
          output: $stdout.isatty ? $stdout : $stderr,
          total: size,
          length: 72,
        }
        options = defaults.merge(options)

        return enum_for(__method__) if !block

        if !options[:hide]
          bar = ProgressBar.create(options)
        end
        RunKit::Term.with_hidden_cursor(options[:output]) do
          each do
            bar&.increment
            yield(_1)
          end
        end
      end
    end

    module Hash
      def hash_sort_by(&) = sort_by(&).to_h
      def sort_by_key = hash_sort_by { _1 }
      def sort_by_value = hash_sort_by { _2 }
      def to_struct = Struct.new(*keys.map(&:to_sym)).new(*values)
    end

    module Numeric
      def sqrt = Math.sqrt(self)
    end

    module Pathname
      # one-liners
      def abs = expand_path
      def cd(...) = FileUtils.cd(self, ...)
      def chmod_r(mode, **kwargs) = FileUtils.chmod_R(mode, self, **kwargs)
      def chown_r(user, group, **kwargs) = FileUtils.chown_R(user, group, self, **kwargs)
      def cp(dest, **kwargs) = FileUtils.cp_r(self, dest, **kwargs.merge(preserve: true))
      def escape = Shellwords.escape(to_s)
      def ln(...) = FileUtils.ln_sf(self, ...)
      def mv(...) = FileUtils.mv(self, ...)
      def rm(...) = FileUtils.rm_f(self, ...)
      def rm_rf(...) = FileUtils.rm_rf(self, ...)
      def touch(...) = FileUtils.touch(self, ...)

      # Replacements for Pathname built-ins removed below.
      def self.included(base)
        base.remove_method :mkdir, :chown, :chmod
      end

      def chmod(mode, **kwargs) = FileUtils.chmod(mode, self, **kwargs)
      def chown(user, group, **kwargs) = FileUtils.chown(user, group, self, **kwargs)
      def mkdir(...) = FileUtils.mkdir_p(self, ...)
    end

    module String
      # remove smart quotes
      def without_curly = tr("“”‘’", "\"\"''")

      # don't judge
      def blue = RunKit::Term.paint_banner(self, :blue)
      def green = RunKit::Term.paint_banner(self, :green)
      def orange = RunKit::Term.paint_banner(self, :peach)
      def red = RunKit::Term.paint_banner(self, :red)
      def muted = RunKit::Term.paint_muted(self)
    end
  end
end

# mix them in
::Enumerable.include RunKit::CoreExt::Enumerable
::Enumerator.include RunKit::CoreExt::Enumerator
::Hash.include RunKit::CoreExt::Hash
::Numeric.include RunKit::CoreExt::Numeric
::Pathname.include RunKit::CoreExt::Pathname
::String.include RunKit::CoreExt::String
