# Sourced by the job's scripts: the stop rules of the data-mining machine, checked before each repository.
#   MAXLOAD     stop when the 1-minute load is above it (default 20)
#   MINFREE     stop when the free space on / is below it, in bytes (default 700000000000)
#   BENCH_KEEP  the name of the bench container that runs all day on the machine; any other bench container (a name
#               that starts with elixir-swe-bench, or an image that starts with elixir-agent-benchmark) means a bench
#               run has started
# guard returns 3 and prints the reason when a rule says stop.
guard() {
  local load free bench
  load=$(cut -d' ' -f1 /proc/loadavg)
  if awk -v l="$load" -v m="${MAXLOAD:-20}" 'BEGIN { exit !(l + 0 > m + 0) }'; then
    echo "STOP: the 1-minute load is $load" >&2; return 3
  fi
  free=$(df -B1 --output=avail / | tail -n 1 | tr -d ' ')
  if [ "$free" -lt "${MINFREE:-700000000000}" ]; then echo "STOP: $free bytes free on /" >&2; return 3; fi
  if ! bench=$(docker ps --format '{{.Names}}	{{.Image}}' 2> /dev/null); then
    echo "STOP: docker ps failed, so a bench run cannot be ruled out" >&2; return 3
  fi
  bench=$(printf '%s\n' "$bench" | awk -F'\t' -v keep="${BENCH_KEEP:-}" 'NF && $1 != keep && ($1 ~ /^elixir-swe-bench/ || $2 ~ /^elixir-agent-benchmark/)' | wc -l)
  if [ "$bench" -gt 0 ]; then echo "STOP: $bench bench containers beside ${BENCH_KEEP:-the standing one}" >&2; return 3; fi
  return 0
}
