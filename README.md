# RunKit [![ci](https://github.com/gurgeous/run_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/gurgeous/run_kit/actions/workflows/ci.yml)

RunKit is a small toolkit for cli. It provides option parsing, shell and file helpers, term colors, and a handful of core extensions.

<img src="./logo.png" width="40%">

### Installation

```ruby
# install gem
$ gem install run_kit

# or add to your Gemfile
gem "run_kit"
```

## RunKit::Options

Featureful cli arg parser based on [spinel-slap](https://github.com/gurgeous/spinel-slap), which combines the best bits from [slop rb](https://github.com/leejarvis/slop) and [clap rs](https://github.com/clap-rs/clap).

```ruby
options = RunKit.parse do |o|
  o.int "-n", "--count <n>", "How many times to run", default: 1
  o.str "--mode <mode>", "Run quickly, or not", choices: %w[fast slow]
  o.positional "<url>", "url to fetch"
end

# #<data count=1, mode="slow", url="https://demo.org", _args=[]>
```

Automatic `--help` for the above. Uses color and wraps to terminal:

<img width="379" height="108" alt="image" src="https://github.com/user-attachments/assets/3d11c8ca-6b57-4dec-9c11-28bf23162ded" />

Flags can also read from ENV:

```ruby
o.bool "--force", env: true              # ENV["FORCE"]
o.str "--token", env: "API_TOKEN"        # ENV["API_TOKEN"]
```

Custom validation:

```ruby
o.validate = lambda do |options|
  raise "--count must be positive" if options.count <= 0
end
```

Also supports subcommands, `git`-style:

```ruby
o.bool "-n", "--dry-run"
o.cmd "build", "Build the project" do |c|
  c.str "--target <target>", default: "release"
end
o.cmd "test", "Run tests" do |c|
  c.bool "--verbose"
end

# myapp build --dry-run --target debug
# => #<data command="build", dry_run=true, target="debug", _args=[]>
```

Put the command first, then global or command flags in any order. If the first
argument isn't a command, a `default: true` command receives all arguments.
Root positionals aren't supported with subcommands; global and command flags
must have distinct switches and keys.

## RunKit::Shell

`RunKit::Shell` is a mixin with many helpers for bin scripts:

| Function                       | Description                                         |
| ------------------------------ | --------------------------------------------------- |
| `csv_read` / `csv_write`       | Read/write CSV (add .gz for gzip)                   |
| `file_read` / `file_write`     | Atomic read/write files (add .gz for gzip)          |
| `json_read` / `json_write`     | Atomic read/write json (add .gz for gzip)           |
| `jsonl_read` / `jsonl_write`   | Atomic read/write jsonl (add .gz for gzip)          |
|                                |
| `csv_write_stdout`             | Write CSV to stdout                                 |
| `csv_write_to_s`               | Convert rows to CSV string                          |
| `gunzip` / `gzip`              | (De)compress a string                               |
| `atomic_write`                 | Atomically replace a file                           |
| `cache_fetch`                  | Populate/fetch from file cache w/ block             |
| `cp_metadata`                  | Copy file metadata from src to dst                  |
| `glob`                         | Find sorted/uniq paths                              |
| `lines_in_file`                | Count lines in file using `wc`                      |
|                                |
| `shell`                        | Run command and return status                       |
| `shell!`                       | Run command or raise                                |
| `shell_transform!`             | Atomically transform from src => dst via cmd        |
| `installed?`                   | Check command availability                          |
| `kill_process`                 | Kill process if present                             |
|                                |
| `banner` / `warning` / `fatal` | Pretty banner in green, orange or red (fatal exits) |
| `program_name`                 | Return executable name                              |
| `prompt?`                      | Ask user for confirmation                           |
| `md5` / `sha256`               | Hash strings                                        |

### RunKit CoreExt

RunKit also installs a small set of core extensions to assist with bin scripts.

| Function                                     | Description               |
| -------------------------------------------- | ------------------------- |
| `Enumerable#mean`                            | Mean                      |
| `Enumerable#stddev`                          | Standard deviation        |
| `Enumerable#variance`                        | Statistical variance      |
| `Enumerable#tally_sorted`                    | Tally and sort values     |
|                                              |
| `Enumerator#with_progressbar`                | Iterate with progress bar |
|                                              |
| `Hash#hash_sort_by`                          | Sort hash                 |
| `Hash#sort_by_key`                           | Sort hash, by keys        |
| `Hash#sort_by_value`                         | Sort hash, by values      |
| `Hash#to_struct`                             | Convert hash to Struct    |
|                                              |
| `Numeric#sqrt`                               | Square root               |
|                                              |
| `Pathname#abs`                               | Expand to absolute path   |
| `Pathname#cd`                                | cd                        |
| `Pathname#chmod`                             | chmod                     |
| `Pathname#chmod_r`                           | chmod recursively         |
| `Pathname#chown`                             | chown                     |
| `Pathname#chown_r`                           | chown recursively         |
| `Pathname#cp`                                | cp -rf                    |
| `Pathname#ln`                                | ln                        |
| `Pathname#mkdir`                             | mkdir -p                  |
| `Pathname#mv`                                | mv                        |
| `Pathname#rm`                                | rm                        |
| `Pathname#rm_rf`                             | rm -rf                    |
| `Pathname#touch`                             | touch                     |
| `Pathname#escape`                            | Escape path for shell     |
|                                              |
| `String#blue` (also green/organge/red/muted) | White text on color bg    |
| `String#without_curly`                       | Replace curly quotes      |

Note: There has been some effort to get the Pathname helpers into Ruby itself, without much success.

### Changelog

#### (unreleased)

- add `csv_write_to_s` for CSV string output
- default subcommands (`default: true`)
- `<url...>` positionals for 1+ values
- remove `naked` and just do the right thing

#### 0.1.5 (Sep 2026)

- after some investigation, decided that naked should default to false

#### 0.1.4 (Sep 2026)

- add subcommand support (`o.cmd`)
- add custom validation (`o.validate`)

#### 0.1.3 (Sep 2026)

- move PROGBAR constant into RunKit::

#### 0.1.2 (Sep 2026)

- allow options to read from ENV

#### 0.1.1 Sep 2026

- add title to progressbar default

#### 0.1.0

- first
