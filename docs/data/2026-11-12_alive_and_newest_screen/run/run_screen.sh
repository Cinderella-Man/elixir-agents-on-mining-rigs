#!/usr/bin/env bash
# Part 2, the screening: the screen step of 2026-11-12_next_ten_screen/run/run_ten.sh with the pilot's scripts
# unchanged, except that the repair test's patches come from git_patches.sh (the clones) instead of GitHub's REST API,
# and the census is the one that job published (not fetched again). It screens every repository whose metadata pages
# are in $RAW/meta: the eight, and the two that job screened, whose tables must come out the same.
#   PILOT   docs/data (the pilot's folders and 2026-11-12_next_ten_screen)
#   RAW     the raw pages of that job (meta/, patches/; titles, bodies and patch text: never committed)
#   WORK    intermediate rows, not committed
#   CENSUS  the census folder (prs_<slug>.tsv.gz)
#   CLONES  the clones (alive_clone.sh)
#   OUT     writes $OUT/screen/
set -euo pipefail
: "${PILOT:?}"; : "${RAW:?}"; : "${WORK:?}"; : "${CENSUS:?}"; : "${CLONES:?}"; : "${OUT:?}"
here="$(cd "$(dirname "$0")" && pwd)"
SCR="$PILOT/2026-11-12_pilot_pr_screen/run"; TEN="$PILOT/2026-11-12_next_ten_screen/run"
. "$here/guard.sh"
guard || exit 3
sw="$WORK/screen"; rm -rf "$sw"; mkdir -p "$OUT/screen"
RAW="$RAW" WORK="$sw" "$SCR/flatten_meta.sh"
CENSUS="$CENSUS" WORK="$sw" "$SCR/relate.sh"
# relate.sh writes no pairs file for a repository with no named pair (none of the pilot's or the earlier job's had none):
# an empty one says so, and the later steps then find no pair to test
for b in "$sw"/base_*.tsv; do s=$(basename "$b" .tsv); s=${s#base_}; [ -f "$sw/pairs_$s.tsv" ] || : > "$sw/pairs_$s.tsv"; done
WORK="$sw" CENSUS="$CENSUS" CLONES="$CLONES" RAW="$RAW" "$here/git_patches.sh"
RAW="$RAW" WORK="$sw" FETCH=0 "$SCR/repair.sh"
WORK="$sw" OUT="$OUT/screen" "$SCR/verdict.sh"
Y0=2012 Y1=2026 OUT="$OUT/screen" "$TEN/screen_summarize.sh"
WORK="$sw" OUT="$OUT/screen" "$SCR/sensitivity.sh"
{ CENSUS="$CENSUS" OUT="$OUT/screen" "$SCR/check.sh" || true; CENSUS="$CENSUS" OUT="$OUT/screen" "$TEN/check_ten.sh"; } | tee "$OUT/screen/checks.txt"
cp "$RAW/patches/git_patches.log" "$OUT/screen/patches_log.tsv"
