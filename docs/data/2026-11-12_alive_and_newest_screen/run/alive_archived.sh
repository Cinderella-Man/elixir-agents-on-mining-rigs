#!/usr/bin/env bash
# Part 1, step 3. Whether each application's repository is archived, from its public page on github.com (no sign-in,
# no API): an archived repository's page carries the banner "This repository was archived by the owner". One request
# every PAUSE seconds (default 4). The page is read and dropped; only the answer is kept.
#   REPOS  select.sh's output (column 1: owner/name)
# Writes a TSV to stdout: repo, HTTP status, the repository the page names after redirects, archived (yes, no, or
# unknown when the page did not load).
set -euo pipefail
: "${REPOS:?}"
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/guard.sh"
PAUSE="${PAUSE:-4}"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf 'repo\thttp_status\tpage_repo\tarchived\n'
fails=0
for repo in $(awk -F'\t' 'NR > 1 { print $1 }' "$REPOS"); do
  guard || exit 3
  out=$(curl -sSL --max-time 30 -A 'Mozilla/5.0 (compatible; repository-check)' -o "$tmp" -w '%{http_code} %{url_effective}' "https://github.com/$repo" 2> /dev/null || echo "000 -")
  code=${out%% *}; url=${out#* }
  page_repo=$(printf '%s\n' "$url" | awk -F/ '{ sub(/[?#].*$/, "", $5); print ($4 != "" && $5 != "") ? $4 "/" $5 : "-" }')
  if [ "$code" = 200 ]; then
    fails=0
    if grep -q -i 'archived by the owner' "$tmp"; then a=yes; else a=no; fi
  else
    a=unknown; fails=$((fails + 1))
    if [ "$code" = 429 ] && [ "$fails" -ge 3 ]; then echo "STOP: github.com answered 429 three times in a row (at $repo)" >&2; exit 4; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$repo" "$code" "$page_repo" "$a"
  : > "$tmp"
  sleep "$PAUSE"
done
