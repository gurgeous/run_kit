#!/usr/bin/env ruby

require_relative "lib/run_kit"

options = RunKit.parse do |o|
  o.int "-n", "--count <n>", "How many times to run", default: 1
  o.str "--mode <mode>", "Run quickly, or not", choices: %w[fast slow]
  o.positional "<url>", "url to fetch"
end

p options
