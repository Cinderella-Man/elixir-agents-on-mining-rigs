#!/usr/bin/env bash
# Part 2: the census tables from the census pages in $RAW: the census step of 2026-11-12_next_ten_screen/run/run_ten.sh
# (the census's flatten.sh and derive.sh, that job's census_summarize.sh), unchanged, for every application whose pages
# are in $RAW (here the five whose pages the earlier job fetched, which must come out as published, and the new ones).
#   PILOT  docs/data     RAW  the raw folder     WORK  intermediate rows     OUT  writes $OUT/census/
set -euo pipefail
: "${PILOT:?}"; : "${RAW:?}"; : "${WORK:?}"; : "${OUT:?}"
CEN="$PILOT/2026-11-11_pilot_pr_census/run"; TEN="$PILOT/2026-11-12_next_ten_screen/run"
mkdir -p "$OUT/census"
flat="$WORK/census_flat"; plain="$WORK/census_plain"
rm -rf "$flat" "$plain"
RAW="$RAW" WORK="$flat" "$CEN/flatten.sh"
WORK="$flat" OUT="$plain" "$CEN/derive.sh"
rm -f "$OUT"/census/prs_*
for f in "$plain"/prs_*.tsv; do gzip -n -c "$f" > "$OUT/census/$(basename "$f").gz"; done
Y0=2012 Y1=2026 OUT="$OUT/census" "$TEN/census_summarize.sh" > /dev/null
cp "$RAW/rate_limit.log" "$OUT/census/fetch_log.txt"
