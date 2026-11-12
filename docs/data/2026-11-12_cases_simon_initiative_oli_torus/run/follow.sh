#!/usr/bin/env bash
# follow.sh: runs beside all.sh until OUT/all.done or OUT/STOP exists, every 5 seconds:
#   - puts every task whose first try is checked, or was dropped as skipped_test, into the hold list (OUT/hold.txt), so
#     that all.sh's closing loop never checks a passed case again for a load reading alone, nor a drop that does not
#     depend on the load (one.sh exits before any step for a held task);
#   - runs the licence scan and the hold-out check (run_scans.sh) on each checked task that has no scan yet, one task
#     at a time.
# Environment: as run_scans.sh (JOB, T, WORK, BENCH_CASES), OUT (default T/out). Prints one line per scan.
set -uo pipefail
: "${JOB:?}" "${T:?}" "${WORK:?}" "${BENCH_CASES:?}"
OUT=${OUT:-$T/out}
touch "$OUT/hold.txt"
while :; do
  if [ -f "$OUT/rows.tsv" ]; then
    # rows.tsv: try, repository, number, id, folder, ..., verdict (10), dropped_at (11), reason (12), ...
    awk -F'\t' 'NR > 1 && $1 == 1 && ($10 == "checked" || $12 == "skipped_test") {print $4}' "$OUT/rows.tsv" |
      while read -r id; do grep -qx "$id" "$OUT/hold.txt" || echo "$id" >> "$OUT/hold.txt"; done
    for id in $(awk -F'\t' 'NR > 1 && $10 == "checked" {print $4}' "$OUT/rows.tsv" | sort -u); do
      [ ! -e "$OUT/scans/$id.done" ] || continue
      JOB=$JOB T=$T WORK=$WORK BENCH_CASES=$BENCH_CASES "$T/run/run_scans.sh" "$id"
      echo "$(date -Is) scanned $id: $(awk -F'\t' -v i="$id" '$1 == i {print $2 " " $7}' "$OUT/scans/scans.tsv")"
    done
  fi
  [ ! -e "$OUT/all.done" ] && [ ! -e "$OUT/STOP" ] || break
  sleep 5
done
echo "$(date -Is) follow.sh ends"
