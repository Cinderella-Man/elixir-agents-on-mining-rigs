#!/usr/bin/env bash
# The whole screen, in order. Needs gh (logged in), jq, awk, gzip.
#   CENSUS the census folder (docs/data/2026-11-11_pilot_pr_census)
#   OUT    the committed folder (screen_*.tsv[.gz], pairs.tsv, summary.tsv, candidates_first.tsv, fetch logs)
#   RAW    raw pages and patches, NOT committed (they hold titles, bodies and diff text)
#   WORK   intermediate rows, not committed
#   REPOS  owner/name list (default: the three pilot applications)
#   FETCH  0 reuses the pages and patches already in $RAW (default 1)
set -euo pipefail
: "${CENSUS:?}"; : "${OUT:?}"; : "${RAW:?}"; : "${WORK:?}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
if [ "${FETCH:-1}" = 1 ]; then RAW="$RAW" "$here/fetch_meta.sh"; fi
rm -rf "$WORK"
RAW="$RAW" WORK="$WORK" "$here/flatten_meta.sh"
CENSUS="$CENSUS" WORK="$WORK" "$here/relate.sh"
RAW="$RAW" WORK="$WORK" FETCH="${FETCH:-1}" "$here/repair.sh"
WORK="$WORK" OUT="$OUT" "$here/verdict.sh"
OUT="$OUT" "$here/summarize.sh"
WORK="$WORK" OUT="$OUT" "$here/sensitivity.sh"
CENSUS="$CENSUS" OUT="$OUT" "$here/check.sh"
for log in rate_limit_meta rate_limit_patches; do [ -f "$RAW/$log.log" ] && cp "$RAW/$log.log" "$OUT/fetch_log_${log#rate_limit_}.txt"; done
true
