#!/usr/bin/env bash
# Tests assemble-site.sh against a temporary tree of fake parts. Requires jq.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/assemble-site.sh"
real_layout="$here/../site-layout.json"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
check() { # check <description> <command...>
  local description=$1; shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}
check_fails() { # check_fails <description> <expected stderr text> <command...>
  local description=$1 expected=$2; shift 2
  local output
  if output=$("$@" 2>&1); then fail "$description (succeeded)"; return; fi
  if printf '%s' "$output" | grep -qF -- "$expected"; then pass "$description"
  else fail "$description (message lacked '$expected': $output)"; fi
}

layout="$tmp/layout.json"
cat > "$layout" <<'JSON'
[
  { "id": "lidded",    "package-path": "A", "product": "a", "site-path": "bins/lidded" },
  { "id": "baseplate", "package-path": "B", "product": "b", "site-path": "baseplate" }
]
JSON

parts="$tmp/parts"
mkdir -p "$parts/site-lidded" "$parts/site-baseplate"
echo lidded > "$parts/site-lidded/index.html"
echo baseplate > "$parts/site-baseplate/index.html"
printf 'wasm-lidded' > "$parts/site-lidded/model.wasm"

# Successful run
site="$tmp/site"
"$script" "$layout" "$parts" "$site" lidded >/dev/null
check "bins/lidded/index.html exists" test -f "$site/bins/lidded/index.html"
check "baseplate/index.html exists" test -f "$site/baseplate/index.html"
check "model.wasm is copied" test -f "$site/bins/lidded/model.wasm"
check "part contents are kept" grep -qx lidded "$site/bins/lidded/index.html"
check ".nojekyll exists" test -f "$site/.nojekyll"
check "root index.html has the refresh meta" grep -qF '<meta http-equiv="refresh" content="0; url=bins/lidded/">' "$site/index.html"
check "root index.html has a visible link" grep -qF '<a href="bins/lidded/">' "$site/index.html"
check "root index.html has no script" bash -c '! grep -qi "<script" "$1"' _ "$site/index.html"
check "root index.html has no absolute URL" bash -c '! grep -qE "https?://|href=\"/" "$1"' _ "$site/index.html"

# Another default id
site2="$tmp/site2"
"$script" "$layout" "$parts" "$site2" baseplate >/dev/null
check "default id selects the redirect target" grep -qF 'url=baseplate/' "$site2/index.html"

# Missing part
rm -rf "$tmp/parts-missing"; cp -R "$parts" "$tmp/parts-missing"; rm -rf "$tmp/parts-missing/site-baseplate"
check_fails "a missing part fails loudly" "missing part for 'baseplate'" "$script" "$layout" "$tmp/parts-missing" "$tmp/site3" lidded
check "a missing part writes no site" test ! -e "$tmp/site3"

# Unknown default id
check_fails "an unknown default id fails" "default id 'nope'" "$script" "$layout" "$parts" "$tmp/site4" nope

# Layout problems
bad() { # bad <name> <json>
  printf '%s\n' "$2" > "$tmp/bad-$1.json"
}
bad dupid '[{"id":"a","site-path":"x"},{"id":"a","site-path":"y"}]'
check_fails "duplicate ids fail" "duplicate layout id 'a'" "$script" "$tmp/bad-dupid.json" "$parts" "$tmp/s" a
bad duppath '[{"id":"a","site-path":"x"},{"id":"b","site-path":"x"}]'
check_fails "duplicate site-paths fail" "duplicate site-path 'x'" "$script" "$tmp/bad-duppath.json" "$parts" "$tmp/s" a
bad dotdot '[{"id":"a","site-path":"../x"}]'
check_fails "a '..' site-path fails" "must not contain" "$script" "$tmp/bad-dotdot.json" "$parts" "$tmp/s" a
bad dotdot2 '[{"id":"a","site-path":"x/../../y"}]'
check_fails "a nested '..' site-path fails" "must not contain" "$script" "$tmp/bad-dotdot2.json" "$parts" "$tmp/s" a
bad abs '[{"id":"a","site-path":"/x"}]'
check_fails "an absolute site-path fails" "must be relative" "$script" "$tmp/bad-abs.json" "$parts" "$tmp/s" a
check "nothing was written outside the site on bad layouts" test ! -e "$tmp/s"

# The real layout
check "the real layout has unique ids" test "$(jq -r '.[].id' "$real_layout" | sort | uniq -d | wc -l)" -eq 0
check "the real layout has unique site-paths" test "$(jq -r '.[]."site-path"' "$real_layout" | sort | uniq -d | wc -l)" -eq 0
check "the real layout assembles with fake parts" bash -c '
  set -e
  p=$1; l=$2; s=$3
  mkdir -p "$p"
  for id in $(jq -r ".[].id" "$l"); do mkdir -p "$p/site-$id"; echo x > "$p/site-$id/index.html"; done
  "$4" "$l" "$p" "$s" lidded' _ "$tmp/real-parts" "$real_layout" "$tmp/real-site" "$script"

if [ "$failures" -ne 0 ]; then echo "$failures check(s) failed"; exit 1; fi
echo "all checks passed"
