#!/usr/bin/env bash
# Assembles the GitHub Pages site from the built customizer parts.
#
# Usage: assemble-site.sh <layout.json> <parts-dir> <site-dir> [default-id]
#
# For each layout entry, copies <parts-dir>/site-<id>/ to <site-dir>/<site-path>/, then writes a
# root index.html that redirects to the default entry (default id: lidded) and a .nojekyll file.
# Requires jq.
set -euo pipefail

die() { echo "assemble-site: error: $*" >&2; exit 1; }

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || die "usage: assemble-site.sh <layout.json> <parts-dir> <site-dir> [default-id]"
layout=$1
parts=$2
site=$3
default_id=${4:-lidded}

command -v jq >/dev/null || die "jq is required"
[ -f "$layout" ] || die "layout file not found: $layout"
[ -d "$parts" ] || die "parts directory not found: $parts"
jq -e 'type == "array" and length > 0 and all(.[]; type == "object")' "$layout" >/dev/null \
  || die "$layout must be a non-empty JSON array of objects"

ids=()
paths=()
while IFS=$'\t' read -r id site_path; do
  [ -n "$id" ] && [ "$id" != "null" ] || die "a layout entry has no id"
  [ -n "$site_path" ] && [ "$site_path" != "null" ] || die "layout entry '$id' has no site-path"
  case "$id" in
    *[!A-Za-z0-9_-]*) die "layout id '$id' may only contain letters, digits, '-' and '_'" ;;
  esac
  case "$site_path" in
    /*) die "site-path '$site_path' of '$id' must be relative (it starts with '/')" ;;
  esac
  case "/$site_path/" in
    */../*|*//*|*/./*) die "site-path '$site_path' of '$id' must not contain '..', '.' or empty segments" ;;
  esac
  for seen in ${ids[@]+"${ids[@]}"}; do
    [ "$seen" != "$id" ] || die "duplicate layout id '$id'"
  done
  for seen in ${paths[@]+"${paths[@]}"}; do
    [ "$seen" != "$site_path" ] || die "duplicate site-path '$site_path'"
  done
  ids+=("$id")
  paths+=("$site_path")
done < <(jq -r '.[] | [(.id // ""), (."site-path" // "")] | @tsv' "$layout")

default_path=
for i in "${!ids[@]}"; do
  [ "${ids[$i]}" != "$default_id" ] || default_path=${paths[$i]}
done
[ -n "$default_path" ] || die "default id '$default_id' is not in $layout"

# Check every part before writing anything.
for id in "${ids[@]}"; do
  [ -d "$parts/site-$id" ] || die "missing part for '$id': $parts/site-$id"
  [ -n "$(ls -A "$parts/site-$id")" ] || die "part for '$id' is empty: $parts/site-$id"
done

mkdir -p "$site"
for i in "${!ids[@]}"; do
  mkdir -p "$site/${paths[$i]}"
  cp -R "$parts/site-${ids[$i]}/." "$site/${paths[$i]}/"
  echo "assembled ${ids[$i]} -> ${paths[$i]}/"
done

cat > "$site/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=${default_path}/">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cadovafinity</title>
</head>
<body>
<p>Redirecting to <a href="${default_path}/">${default_path}/</a>.</p>
</body>
</html>
HTML

: > "$site/.nojekyll"
echo "wrote $site/index.html (redirect to ${default_path}/) and $site/.nojekyll"
