#!/usr/bin/env bash
# wait_cases.sh: return when a run of run_all.sh has ended N cases, has written OUT/DONE, or its driver is gone;
# then print the counts by exit code, the last lines of the log and the marker.
# Environment: OUT (the run's folder). Usage: wait_cases.sh <N>
set -u
: "${OUT:?}"
n=${1:?count}
ended() { echo $(($(wc -l < "$OUT/tasks.tsv") - 1)); }
while [ ! -e "$OUT/DONE" ] && [ "$(ended)" -lt "$n" ] && kill -0 "$(cat "$OUT/driver.pid")" 2> /dev/null; do
  sleep 20
done
echo "ended: $(ended)"
awk -F'\t' 'NR > 1 { c[$2]++; s += $5 } END { for (k in c) printf "exit %s: %d\n", k, c[k]; printf "seconds: %d\n", s }' \
  "$OUT/tasks.tsv"
tail -n 4 "$OUT/run.log"
if [ -e "$OUT/DONE" ]; then
  echo "marker: $(cat "$OUT/DONE")"
elif kill -0 "$(cat "$OUT/driver.pid")" 2> /dev/null; then
  echo "marker: none, the driver runs"
else
  echo "marker: none, THE DRIVER IS GONE"
fi
