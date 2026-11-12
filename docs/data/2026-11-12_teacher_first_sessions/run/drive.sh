#!/usr/bin/env bash
# drive.sh: the teacher solves a list of tasks, one at a time, one attempt each: one factory run per task, started
# only when the last one has ended, so no preparation and no other attempt of this job runs beside a session.
# Beside it, metrics_log.py records the model server's own per-request timings.
# For each task in TASKS (one id per line, in order):
#   1. the stop rules are read (below); a rule that holds ends the list;
#   2. start_run on that one task with the engine's defaults (no settings), the key read from KEY_FILE inside the
#      controller (the file is mounted there read only) and passed as start_run's `key` option;
#   3. every TICK seconds: the controller's status, and the stop rules; a rule that holds stops the run (Runs.stop/0);
#   4. when the run has ended: its record, its attempt and its kept list are written under OUT/cases/<id>/.
# Stop rules: a bench run on this Docker (a container named eab-* or elixir-swe-bench*, or of an
# elixir-agent-benchmark image, other than BENCH_CONTROLLER); free space on / under MIN_FREE bytes; the server busy
# with another request (not idle before a start, or a request queued) for QUEUE_LIMIT seconds; three sessions in a
# row that end with a model error, or three in a row with no tool call.
# Environment: CTL, NAME (the controller's container), SRC (the factory folder: bin/factoryctl), CONTROLLER (this
# folder's controller.sh), MODEL_URL (without /v1), KEY_FILE (the server's key, a file on this machine), TASKS, OUT,
# TICK (20), QUEUE_LIMIT (600), MIN_FREE (50000000000), BENCH_CONTROLLER (elixir-swe-bench-benchmark-1), INTERVAL
# (10, for metrics_log.py); ADOPT_RUN, ADOPT_TASK and ADOPT_STARTED (optional: a run an earlier start of this driver
# began on that task at that time, which this driver then watches and records instead of starting the task again).
# Writes OUT/drive.log (one line per event), OUT/cases.tsv (one line per task), OUT/cases/<id>/, OUT/metrics/ (the
# logger's files), OUT/stop_reason when a rule ended the list, and OUT/drive.done (the count of tasks run) last.
set -uo pipefail
: "${CTL:?}" "${NAME:?}" "${SRC:?}" "${CONTROLLER:?}" "${MODEL_URL:?}" "${KEY_FILE:?}" "${TASKS:?}" "${OUT:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
TICK=${TICK:-20}
QUEUE_LIMIT=${QUEUE_LIMIT:-600}
MIN_FREE=${MIN_FREE:-50000000000}
INTERVAL=${INTERVAL:-10}
BENCH_CONTROLLER=${BENCH_CONTROLLER:-elixir-swe-bench-benchmark-1}
mkdir -p "$OUT/cases" "$OUT/metrics"
rm -f "$OUT/drive.done" "$OUT/stop_reason" "$OUT/metrics/logger.stop"
log() { echo "$(date -u +%FT%TZ) $*" >> "$OUT/drive.log"; }
ctl() { NAME=$NAME "$SRC/bin/factoryctl" "$@"; }
rpc() { CTL=$CTL NAME=$NAME "$CONTROLLER" rpc "$1" | grep '^{'; }

MODEL_URL=$MODEL_URL KEY_FILE=$KEY_FILE OUT=$OUT/metrics INTERVAL=$INTERVAL \
  python3 -I "$RUN/metrics_log.py" >> "$OUT/metrics/logger.out" 2>&1 &
logger=$!
trap 'touch "$OUT/metrics/logger.stop"; wait "$logger" 2>/dev/null' EXIT

bench_running() {
  docker ps --format '{{.Names}} {{.Image}}' |
    awk -v c="$BENCH_CONTROLLER" '$1 != c && ($1 ~ /^eab-/ || $1 ~ /^elixir-swe-bench/ || $2 ~ /^elixir-agent-benchmark/)' |
    grep -q .
}
free_bytes() { df -B1 --output=avail / | tail -n 1 | tr -d ' '; }
# The logger's last read, when it is fresh (younger than 5 reads); empty otherwise.
live() {
  jq -r --argjson now "$(date +%s)" --argjson max $((INTERVAL * 5)) \
    "if (\$now - .read_at) < \$max then (.live.$1 // empty) else empty end" "$OUT/metrics/latest.json" 2>/dev/null
}

# Sets REASON and returns 0 when a rule holds. BUSY_SINCE keeps the start of a busy server across calls.
BUSY_SINCE=
REASON=
stop_rule() {
  local mode=$1 free state queued now
  REASON=
  if bench_running; then REASON="bench_run: a bench run's container is up"; return 0; fi
  free=$(free_bytes)
  if [ "$free" -lt "$MIN_FREE" ]; then REASON="disk: $free bytes free on /"; return 0; fi
  state=$(live state); queued=$(live queued); now=$(date +%s)
  if { [ "$mode" = before ] && [ -n "$state" ] && [ "$state" != idle ]; } || [ "${queued:-0}" -gt 0 ]; then
    BUSY_SINCE=${BUSY_SINCE:-$now}
    if [ $((now - BUSY_SINCE)) -ge "$QUEUE_LIMIT" ]; then
      REASON="busy: the server was busy with another request (state $state, queued $queued) for $((now - BUSY_SINCE)) s"
      return 0
    fi
  else
    BUSY_SINCE=
  fi
  return 1
}

# A restarted driver keeps the lines of the tasks already recorded.
[ -s "$OUT/cases.tsv" ] ||
  printf 'id\trun\tstarted\tended\trun_status\tattempt_status\tattempt_reason\tcalls\ttool_calls\tmodel_error\tkept\tnote\n' \
    > "$OUT/cases.tsv"
errors=0 no_tools=0 done_count=0 stop=
sleep 15  # the logger's first reads
log "start: $(grep -c . "$TASKS") tasks; free $(free_bytes) bytes"
while IFS= read -r id <&3; do
  [ -n "$id" ] || continue
  dir=$OUT/cases/$id
  mkdir -p "$dir"
  if [ -n "${ADOPT_RUN:-}" ] && [ "$id" = "${ADOPT_TASK:-}" ]; then
    # A run this driver's earlier start began on this task and then lost (ADOPT_RUN, from ADOPT_STARTED): watched and
    # recorded as its own, never started again.
    started=${ADOPT_STARTED:?}
    printf '{"ok": "%s", "adopted": true}\n' "$ADOPT_RUN" > "$dir/start_run.json"
  else
    # 1. before the task: wait while the server is busy with another request, up to QUEUE_LIMIT
    BUSY_SINCE=
    while :; do
      if stop_rule before; then stop=$REASON; break 2; fi
      [ -z "$BUSY_SINCE" ] && break
      sleep "$TICK"
    done
    cp "$OUT/metrics/latest.json" "$dir/metrics_before.json" 2>/dev/null
    started=$(date -u +%FT%TZ)
    # 2. one run on this one task; the key goes from the file to start_run's option, never through a log
    rpc "k = \"/secrets/model_key\" |> File.read!() |> String.trim(); r = Eab.Factory.start_run(\"$MODEL_URL\", [\"$id\"], %{}, key: k); IO.puts(Jason.encode!(case r do {:ok, v} -> %{\"ok\" => v}; {:error, e} -> %{\"error\" => e} end))" \
      > "$dir/start_run.json" 2>&1
  fi
  # start_run answers with the run's id
  run=$(jq -r '.ok | if type == "string" then . elif type == "object" then (.id // empty) else empty end' \
    "$dir/start_run.json" 2>/dev/null)
  if [ -z "$run" ]; then
    log "ERROR start_run $id: $(head -c 400 "$dir/start_run.json" | tr '\n' ' ')"
    printf '%s\t\t%s\t%s\tnot_started\t\t\t\t\t\t\t%s\n' "$id" "$started" "$(date -u +%FT%TZ)" "start_run refused" \
      >> "$OUT/cases.tsv"
    stop="start_run: refused for $id"; break
  fi
  log "run $id: $run started"
  # 3. wait for the run to end, reading the stop rules
  stopped_by= BUSY_SINCE=
  while :; do
    sleep "$TICK"
    ctl status > "$dir/status.json" 2>/dev/null
    if jq -e '.ok.run == null' "$dir/status.json" > /dev/null 2>&1; then break; fi
    if [ -z "$stopped_by" ] && stop_rule during; then
      stopped_by=$REASON
      log "STOP during $id: $REASON; stopping run $run"
      rpc 'IO.puts(Jason.encode!(%{"stop" => inspect(Eab.Runs.stop())}))' >> "$dir/stop.json" 2>&1
    fi
  done
  ended=$(date -u +%FT%TZ)
  cp "$OUT/metrics/latest.json" "$dir/metrics_after.json" 2>/dev/null
  # 4. the record
  ctl kept "$run" > "$dir/kept.json" 2>&1
  rdir=$CTL/data/runs/$run
  cp "$rdir/run.json" "$dir/run.json" 2>/dev/null
  cp "$rdir/$id/attempt.json" "$dir/attempt.json" 2>/dev/null
  cp "$rdir/$id/agent-progress.json" "$dir/agent-progress.json" 2>/dev/null
  run_status=$(jq -r '.status // empty' "$dir/run.json" 2>/dev/null)
  a_status=$(jq -r '.status // empty' "$dir/attempt.json" 2>/dev/null)
  a_reason=$(jq -r '.reason // .stop_reason // empty' "$dir/attempt.json" 2>/dev/null)
  calls=$(jq -r '.calls // empty' "$dir/agent-progress.json" 2>/dev/null)
  m_error=$(jq -r '.error // empty' "$dir/agent-progress.json" 2>/dev/null | head -c 200 | tr '\t\n' '  ')
  tools=$(cat "$rdir/$id"/response-*.sse 2>/dev/null | grep '^data: {"type": "content_block_start"' | grep -c '"tool_use"')
  kept=$(jq -r '[.ok.kept[]?.case] | length' "$dir/kept.json" 2>/dev/null)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$run" "$started" "$ended" "$run_status" \
    "$a_status" "$a_reason" "$calls" "$tools" "${m_error:+yes}" "$kept" "$stopped_by" >> "$OUT/cases.tsv"
  log "run $id: $run ended: run $run_status, attempt $a_status ($a_reason), $calls calls, $tools tool calls, kept $kept${m_error:+, model error: $m_error}"
  done_count=$((done_count + 1))
  if [ -n "$stopped_by" ]; then stop=$stopped_by; break; fi
  if [ -n "$m_error" ]; then errors=$((errors + 1)); else errors=0; fi
  if [ "${tools:-0}" -eq 0 ]; then no_tools=$((no_tools + 1)); else no_tools=0; fi
  if [ "$errors" -ge 3 ]; then stop="model_errors: three sessions in a row ended with a model error"; break; fi
  if [ "$no_tools" -ge 3 ]; then stop="no_tools: three sessions in a row with no tool call"; break; fi
done 3< "$TASKS"
[ -n "$stop" ] && { echo "$stop" > "$OUT/stop_reason"; log "STOP: $stop"; }
log "end: $done_count tasks run"
echo "$done_count" > "$OUT/drive.done"
