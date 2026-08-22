default: test

#
# check and friends
#

check:
  if [ "{{os()}}" != "windows" ]; then just lint ; fi
  just test
  just banner "✓ check ✓"

fmt: (lint "-a")

outdated:
  just banner Here are the easy ones:
  bundle outdated --filter-minor || true
  just banner The full list:
  bundle outdated || true

pry:
  bundle exec pry -I lib -r run_kit.rb

lint *ARGS:
  just banner lint...
  rubocop {{ARGS}}

test *ARGS:
  just banner rake test {{ARGS}}
  rake test {{ARGS}}

# run tests repeatedly
test-watch *ARGS:
  watchexec --stop-timeout=0 --clear clear just test "{{ARGS}}"

#
# publish
#

gem-local:
  just banner rake install:local...
  rake install:local

publish: check
  just banner rake release...
  rake release
  just banner "✓ publish ✓"


#
# banner
#

set quiet

banner +ARGS:  (_banner '\e[48;2;064;160;043m' ARGS)
warning +ARGS: (_banner '\e[48;2;251;100;011m' ARGS)
fatal +ARGS:   (_banner '\e[48;2;210;015;057m' ARGS)
  exit 1
_banner BG +ARGS:
  printf '\e[38;5;231m{{BOLD+BG}}[%s] %-72s {{NORMAL}}\n' "$(date +%H:%M:%S)" "{{ARGS}}"
