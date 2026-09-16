#!/usr/bin/env ruby

require_relative "lib/run_kit"

options = RunKit.parse do |o|
  o.version = "1.0"
  o.bool "--dry-run", "Preview without making changes"

  o.cmd "fetch", "Fetch a URL" do |c|
    c.int "-n", "--count <n>", "How many times to run", default: 1
    c.str "--mode <mode>", "Run quickly, or not", choices: %w[fast slow]
    c.positional "<url>", "URL to fetch"
  end

  o.cmd "build", "Build the project" do |c|
    c.naked = false
    c.str "--target <target>", "Build target", choices: %w[debug release], default: "release"
    c.bool "--force", "Force a rebuild", env: "DEMO_FORCE"
  end
end

p options
