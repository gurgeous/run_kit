Gem::Specification.new do |s|
  s.name = "run_kit"
  s.version = "0.1.0"
  s.authors = ["Adam Doppelt"]
  s.email = "amd@gurge.com"
  s.summary = "Run kit."
  s.homepage = "https://github.com/gurgeous/run_kit"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.2.0"
  s.metadata = {
    "homepage_uri" => s.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => s.homepage,
  }

  # what's in the gem?
  s.files = `git ls-files`.split("\n").grep_v(%r{^(bin|test)/})
  s.require_paths = ["lib"]

  # gem dependencies
  s.add_dependency "csv", "~> 3.3"
  s.add_dependency "ruby-progressbar", "~> 1.13"
end
