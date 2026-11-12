#!/usr/bin/env bash
# Steps 2 and 3 after fetch_one.sh has filled $RAW: the census tables, then the screening tables, with the pilot's own
# scripts (docs/data/2026-11-11_pilot_pr_census/run and docs/data/2026-11-12_pilot_pr_screen/run) wherever they run
# unchanged, and the three copies in this folder (fetch_census.sh, census_summarize.sh, screen_summarize.*) where the
# pilot's did not fit these repositories. Needs gh (logged in), jq, awk, gzip.
#   PILOT  the folder holding the pilot's two data folders (docs/data)
#   RAW    the raw pages fetch_one.sh wrote (titles and bodies: NOT committed); the patches go to $RAW/patches
#   WORK   intermediate rows, not committed
#   OUT    the committed folder: census/ and screen/ are written there
#   Y0, Y1 first and last year of the year columns (default 2012 and 2026)
#   STEPS  "census screen" (default), or one of them
# Before the REST fetch of per-file patches it checks GitHub's REST budget and stops, writing nothing more, if the
# pull requests it needs (and a reserve of 300) would not fit.
set -euo pipefail
: "${PILOT:?}"; : "${RAW:?}"; : "${WORK:?}"; : "${OUT:?}"
Y0="${Y0:-2012}"; Y1="${Y1:-2026}"; STEPS="${STEPS:-census screen}"
here="$(cd "$(dirname "$0")" && pwd)"
CEN="$PILOT/2026-11-11_pilot_pr_census/run"; SCR="$PILOT/2026-11-12_pilot_pr_screen/run"
mkdir -p "$OUT/census" "$OUT/screen" "$WORK"
for s in $STEPS; do
  case "$s" in
  census)
    flat="$WORK/census_flat"; plain="$WORK/census_plain"      # (in bash a prefix assignment is visible to the next one)
    rm -rf "$flat" "$plain"
    RAW="$RAW" WORK="$flat" "$CEN/flatten.sh"
    WORK="$flat" OUT="$plain" "$CEN/derive.sh"
    rm -f "$OUT"/census/prs_*
    for f in "$plain"/prs_*.tsv; do gzip -n -c "$f" > "$OUT/census/$(basename "$f").gz"; done
    Y0="$Y0" Y1="$Y1" OUT="$OUT/census" "$here/census_summarize.sh" > /dev/null
    cp "$RAW/rate_limit.log" "$OUT/census/fetch_log.txt"
    ;;
  screen)
    sw="$WORK/screen"; rm -rf "$sw"
    RAW="$RAW" WORK="$sw" "$SCR/flatten_meta.sh"
    CENSUS="$OUT/census" WORK="$sw" "$SCR/relate.sh"
    # the pull requests whose patches the repair test needs: the rule of repair.sh (pairs that are not a revert, where both
    # pull requests change code or tests), counted here to check the REST budget first
    need=$(for p in "$sw"/pairs_*.tsv; do awk -F'\t' '$6 == 0 && $8 > 0 && $9 > 0 { print FILENAME "\t" $1; print FILENAME "\t" $2 }' "$p"; done | sort -u | wc -l)
    have=$(gh api rate_limit --jq '.resources.core.remaining')
    echo "patch fetch: about $need pull requests (some need more than one page), REST budget remaining $have"
    if [ "$have" -lt $((need + need / 10 + 300)) ]; then echo "STOP: the REST budget would run out" >&2; exit 3; fi
    RAW="$RAW" WORK="$sw" FETCH=1 "$SCR/repair.sh"
    WORK="$sw" OUT="$OUT/screen" "$SCR/verdict.sh"
    Y0="$Y0" Y1="$Y1" OUT="$OUT/screen" "$here/screen_summarize.sh"
    WORK="$sw" OUT="$OUT/screen" "$SCR/sensitivity.sh"
    # the pilot's checks, then check 2 again with the reverted-later rule (see check_ten.sh); the first may print one FAIL for it
    { CENSUS="$OUT/census" OUT="$OUT/screen" "$SCR/check.sh" || true; CENSUS="$OUT/census" OUT="$OUT/screen" "$here/check_ten.sh"; } | tee "$OUT/screen/checks.txt"
    cp "$RAW/rate_limit_meta.log" "$OUT/screen/fetch_log_meta.txt"
    [ -f "$RAW/rate_limit_patches.log" ] && cp "$RAW/rate_limit_patches.log" "$OUT/screen/fetch_log_patches.txt"
    ;;
  esac
done
