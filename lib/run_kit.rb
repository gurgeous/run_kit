require "csv"
require "digest"
require "fileutils"
require "io/console"
require "json"
require "open3"
require "pathname"
require "ruby-progressbar"
require "shellwords"
require "stringio"
require "tempfile"
require "zlib"

require_relative "run_kit/core_ext"
require_relative "run_kit/term"
require_relative "run_kit/options"
require_relative "run_kit/shell"

module RunKit
  PROGRESSBAR = {
    format: "%t: %j%% %B #{Term.paint_ansi("%c/%u %e", Term.ansi256_fg(242))}",
    progress_mark: Term.paint_ansi("━", Term.ansi256_fg(46)),
    remainder_mark: Term.paint_ansi("━", Term.ansi256_fg(237)),
    length: 72,
  }

  # handy entry point for RunKit::Options
  def self.parse(...) = Options.parse(...)
end
