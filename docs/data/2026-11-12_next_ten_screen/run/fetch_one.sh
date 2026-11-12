#!/usr/bin/env bash
# Step 1. The census pages and the screening's metadata pages of ONE repository, fetched one after the other (so that the
# two row counts agree), with the pilot's own fetch scripts. Checks GitHub's GraphQL budget first and stops, writing
# nothing, if the repository's pages (and a reserve) would not fit in what is left.
#   $1     owner/name
#   PILOT  the pilot's two run folders' parent (docs/data)
#   RAW    shared raw folder (NOT committed: pages hold titles and bodies); writes $RAW/<owner>__<name>/ (census pages),
#          $RAW/meta/<owner>__<name>/ (metadata pages) and appends to $RAW/logs/
#   PRS    merged pull requests of the repository now (from state.tsv), to estimate the pages
#   RESERVE  GraphQL points to keep unspent (default 300)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$1"; : "${PILOT:?}"; : "${RAW:?}"; : "${PRS:?}"; RESERVE="${RESERVE:-300}"
slug="${repo/\//__}"
mkdir -p "$RAW/logs" "$RAW/meta" "$RAW/tmp_$slug"
need=$(( 2 * (PRS / 30 + 2) + RESERVE ))
have=$(gh api rate_limit --jq '.resources.graphql.remaining')
if [ "$have" -lt "$need" ]; then
  echo "STOP $repo: GraphQL remaining $have, needs about $need (2 x $((PRS / 30 + 2)) pages and a reserve of $RESERVE)" | tee -a "$RAW/logs/stopped.txt"
  exit 3
fi
echo "$(date -u +%FT%TZ) $repo: GraphQL remaining $have, needs about $need" >> "$RAW/logs/budget_checks.txt"
REPOS="$repo" RAW="$RAW/tmp_$slug/census" bash "$here/fetch_census.sh" > "$RAW/logs/census_$slug.log" 2>&1
REPOS="$repo" RAW="$RAW/tmp_$slug/screen" bash "$PILOT/2026-11-12_pilot_pr_screen/run/fetch_meta.sh" > "$RAW/logs/meta_$slug.log" 2>&1
rm -rf "$RAW/$slug" "$RAW/meta/$slug"
mv "$RAW/tmp_$slug/census/$slug" "$RAW/$slug"
mv "$RAW/tmp_$slug/screen/meta/$slug" "$RAW/meta/$slug"
cat "$RAW/tmp_$slug/census/rate_limit.log" >> "$RAW/rate_limit.log"
cat "$RAW/tmp_$slug/screen/rate_limit_meta.log" >> "$RAW/rate_limit_meta.log"
rm -rf "$RAW/tmp_$slug"
echo "$(date -u +%FT%TZ) $repo: done" >> "$RAW/logs/budget_checks.txt"
