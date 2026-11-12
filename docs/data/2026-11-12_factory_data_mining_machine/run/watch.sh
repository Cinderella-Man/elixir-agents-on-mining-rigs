#!/usr/bin/env bash
# watch.sh: sample the machine every INTERVAL seconds (default 10) until the file STOP exists: the time, the
# 1-minute load, free bytes on /, available memory. One tab-separated line per sample to standard output.
set -uo pipefail
: "${STOP:?STOP=<a file whose existence ends the watch>}"
INTERVAL=${INTERVAL:-10}
printf 'time\tload1\tfree_bytes\tmem_available_bytes\n'
until [ -e "$STOP" ]; do
  printf '%s\t%s\t%s\t%s\n' "$(date -Is)" "$(cut -d' ' -f1 /proc/loadavg)" "$(df --output=avail -B1 / | tail -1 | tr -d ' ')" \
    "$(awk '/MemAvailable/ {print $2 * 1024}' /proc/meminfo)"
  sleep "$INTERVAL"
done
