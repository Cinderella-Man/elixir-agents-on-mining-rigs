#!/usr/bin/env bash
# watch.sh: samples the data-mining machine every INTERVAL seconds (10) until the file END exists, and applies the
# job's stop rules:
#   - free bytes on / under MIN_FREE (50,000,000,000);
#   - the 1-minute load above MAX_LOAD (26) in two readings LOAD_EVERY seconds apart (300);
#   - a bench run: a running container of the bench's images (BENCH_IMAGE, a prefix) or names (BENCH_NAME, a prefix)
#     other than its controller BENCH_CONTROLLER.
# On a stop it writes STOP (the reason on its first line, then the running containers and the busiest processes),
# saves the controller's log to CTL/logs/controller.log and stops every container that carries JOB_LABEL, the
# controller included (the containers stay, as does their data).
# Output, to standard output: one tab-separated line per sample: the time, the 1-minute load, free bytes on /,
# available memory in bytes, and the running containers counted as this job's / other task jobs' (TASK_LABEL) / others.
set -uo pipefail
: "${END:?}" "${STOP:?}" "${CTL:?}" "${NAME:?}" "${JOB_LABEL:?JOB_LABEL=<key=value>}" "${TASK_LABEL:?}"
INTERVAL=${INTERVAL:-10}
MIN_FREE=${MIN_FREE:-50000000000}
MAX_LOAD=${MAX_LOAD:-26}
LOAD_EVERY=${LOAD_EVERY:-300}
BENCH_IMAGE=${BENCH_IMAGE:-elixir-agent-benchmark}
BENCH_NAME=${BENCH_NAME:-eab-}
BENCH_CONTROLLER=${BENCH_CONTROLLER:-elixir-swe-bench-benchmark-1}

stop_job() {
  {
    echo "$1"
    date -Is
    cat /proc/loadavg
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Labels}}'
    ps -eo pid,user,pcpu,pmem,etime,comm --sort=-pcpu | head -n 25
  } > "$STOP.tmp"
  mv "$STOP.tmp" "$STOP"
  mkdir -p "$CTL/logs"
  docker logs "$NAME" > "$CTL/logs/controller.log" 2>&1 || true
  ids=$(docker ps -q --filter "label=$JOB_LABEL")
  # shellcheck disable=SC2086
  [ -z "$ids" ] || docker stop $ids > /dev/null
}

printf 'time\tload1\tfree_bytes\tmem_available_bytes\tcontainers_job_task_other\n'
last_load_at=0; last_high=0
until [ -e "$END" ] || [ -e "$STOP" ]; do
  now=$(date +%s)
  load=$(cut -d' ' -f1 /proc/loadavg)
  free=$(df --output=avail -B1 / | tail -1 | tr -d ' ')
  rows=$(docker ps --format "{{.Names}}\t{{.Image}}\t{{.Label \"${JOB_LABEL%%=*}\"}}\t{{.Label \"${TASK_LABEL%%=*}\"}}")
  counts=$(printf '%s\n' "$rows" | awk -F'\t' -v j="${JOB_LABEL#*=}" -v t="${TASK_LABEL#*=}" \
    'NF {if ($3 == j) a++; else if ($4 == t) b++; else c++} END {printf "%d/%d/%d", a, b, c}')
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$load" "$free" "$(awk '/MemAvailable/ {print $2 * 1024}' /proc/meminfo)" "$counts"
  bench=$(printf '%s\n' "$rows" | awk -F'\t' -v i="$BENCH_IMAGE" -v n="$BENCH_NAME" -v c="$BENCH_CONTROLLER" \
    'NF && $1 != c && (index($2, i) == 1 || index($1, n) == 1) {print $1 " (" $2 ")"}' | head -n 3 | tr '\n' ' ')
  if [ -n "$bench" ]; then stop_job "stop: a bench run started: $bench"; break; fi
  if [ "$free" -lt "$MIN_FREE" ]; then stop_job "stop: free bytes on / $free, under $MIN_FREE"; break; fi
  if [ $((now - last_load_at)) -ge "$LOAD_EVERY" ]; then
    high=$(awk -v l="$load" -v m="$MAX_LOAD" 'BEGIN {print (l > m ? 1 : 0)}')
    if [ "$high" = 1 ] && [ "$last_high" = 1 ]; then
      stop_job "stop: the 1-minute load was above $MAX_LOAD in two readings $LOAD_EVERY s apart (now $load)"; break
    fi
    last_high=$high; last_load_at=$now
  fi
  sleep "$INTERVAL"
done
