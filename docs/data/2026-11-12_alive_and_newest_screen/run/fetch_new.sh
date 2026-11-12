#!/usr/bin/env bash
# Part 2: the census pages and the screening's metadata pages of the applications that have none yet, with the earlier
# job's fetch_one.sh (and through it the census's and the pilot's fetch scripts) unchanged, their `gh` calls served by
# run/shim/gh (curl and a token). One application at a time, the stop rules checked before each.
#   PILOT   docs/data       RAW  the raw folder (pages hold titles and bodies: never committed)
#   REPOS   select.sh's output (its merged_prs_pool column sizes the budget check)
#   SKIP    owner/name to leave out (those with pages already, and the pilot's), separated by spaces
#   LAST    owner/name to fetch last (the largest), separated by spaces
#   GITHUB_TOKEN_FILE  the token's file (read by the stand-in only)
# Writes $RAW/<slug>/, $RAW/meta/<slug>/, $RAW/logs/, and $RAW/logs/gh_requests.tsv (time, endpoint, HTTP status).
set -euo pipefail
: "${PILOT:?}"; : "${RAW:?}"; : "${REPOS:?}"; : "${GITHUB_TOKEN_FILE:?}"
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/guard.sh"
export PATH="$here/shim:$PATH" GH_SHIM_LOG="$RAW/logs/gh_requests.tsv" GH_SHIM_STOP="$RAW/logs/gh_stop.txt"
mkdir -p "$RAW/logs"; rm -f "$GH_SHIM_STOP" "$GH_SHIM_STOP.count"
order=$(awk -F'\t' -v skip=" ${SKIP:-} " -v last=" ${LAST:-} " 'NR > 1 && index(skip, " " $1 " ") == 0 { if (index(last, " " $1 " ")) l = l " " $1; else print $1 } END { n = split(l, a, " "); for (i = 1; i <= n; i++) print a[i] }' "$REPOS")
for repo in $order; do
  slug="${repo/\//__}"
  [ -d "$RAW/meta/$slug" ] && { echo "$repo: pages already fetched"; continue; }
  guard || exit 3
  [ -f "$GH_SHIM_STOP" ] && { echo "STOP before $repo: $(cat "$GH_SHIM_STOP")"; exit 4; }
  prs=$(awk -F'\t' -v r="$repo" '$1 == r { print $5 }' "$REPOS")
  t0=$(date +%s)
  if PILOT="$PILOT" RAW="$RAW" PRS="$prs" bash "$PILOT/2026-11-12_next_ten_screen/run/fetch_one.sh" "$repo"; then
    echo "$repo: $(ls "$RAW/$slug" | wc -l) census pages, $(ls "$RAW/meta/$slug" | wc -l) metadata pages, $(( $(date +%s) - t0 )) s"
  else
    rc=$?; echo "$repo: fetch_one.sh ended with $rc"; [ -f "$GH_SHIM_STOP" ] && cat "$GH_SHIM_STOP"; exit "$rc"
  fi
done
echo "requests by HTTP status: $(cut -f3 "$GH_SHIM_LOG" | sort | uniq -c | tr '\n' ' ')"
