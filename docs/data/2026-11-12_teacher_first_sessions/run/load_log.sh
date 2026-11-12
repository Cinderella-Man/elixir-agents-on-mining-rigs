#!/usr/bin/env bash
# load_log.sh: the data-mining machine's load once a minute while drive.sh runs: the time (UTC), the 1-, 5- and
# 15-minute load averages and the count of running containers (every job's, not only this one's), to OUT/load.log,
# until OUT/drive.done exists. Started by hand beside drive.sh, at 12:37 UTC.
# Environment: OUT (drive.sh's out folder).
set -u
: "${OUT:?}"
while [ ! -f "$OUT/drive.done" ]; do
  echo "$(date -u +%FT%TZ) $(cut -d" " -f1-3 /proc/loadavg) $(docker ps -q | wc -l)" >> "$OUT/load.log"
  sleep 60
done
