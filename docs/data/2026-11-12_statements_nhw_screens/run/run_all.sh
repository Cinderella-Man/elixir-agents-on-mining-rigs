#!/usr/bin/env bash
# run_all.sh: the statements of a list of cases, one case at a time, on the data-mining machine.
# The driver of docs/data/2026-11-12_statements_first_20/run/run_all.sh, with these changes: the free-space line is
# 50,000,000,000 bytes; the containers' names start with PREFIX; a second label may be given; a case that ended with
# no accepted answer (exit 10) is not asked again on a restart; a case folder that already holds a statement this run
# did not write stops the run; records of an earlier, stopped start of a case are moved aside, never deleted.
# Each case runs factory/tools/statements/write_statement.exs in its own tooling container; the next starts when it
# has ended. Before each case: no bench run container is up (a name starting with "eab-") and the root file system
# has at least MIN_FREE bytes free; otherwise the run stops. It also stops on a case that ends with three server
# errors in a row (13), a busy server (14) or a tool error (any code but 0 and 10).
# Environment:
#   WORK        the factory's work folder (case folders in WORK/tasks)
#   TOOLS       the folder holding statement.ex, write_statement.exs and instruction.md
#   CLONES      a folder under which the bare Git clones holding the cases' commits live
#   OUT         where the records go: OUT/<case id>/..., OUT/tasks.tsv, OUT/run.log, OUT/props.json, OUT/DONE
#   MODEL_URL   the server's OpenAI-style base URL (ending in /v1), reached from the containers (host network)
#   KEY_FILE    the file that holds the server's key (mounted read only; never printed)
#   MODEL       the served model's name
#   WRITER_MODEL, WRITER_FILE, WRITER_PRESET   the writer's id for statement.json
#   IMAGE       the tooling image; LABEL (key=value); JOB_LABEL (a second key=value, optional)
#   PREFIX      the start of every container's name (etf-statements2); CPU_SHARES (256); MIN_FREE (50000000000)
# Usage: run_all.sh <case list: "<folder under WORK/tasks><TAB><clone under CLONES>" per line>
set -uo pipefail
: "${WORK:?}" "${TOOLS:?}" "${CLONES:?}" "${OUT:?}" "${MODEL_URL:?}" "${KEY_FILE:?}" "${MODEL:?}" "${IMAGE:?}"
: "${WRITER_MODEL:?}" "${WRITER_FILE:?}" "${WRITER_PRESET:?}" "${LABEL:?LABEL=<key=value>}"
PREFIX=${PREFIX:-etf-statements2}
CPU_SHARES=${CPU_SHARES:-256}
MIN_FREE=${MIN_FREE:-50000000000}
labels=(--label "$LABEL")
[ -z "${JOB_LABEL:-}" ] || labels+=(--label "$JOB_LABEL")
list=${1:?case list}
mkdir -p "$OUT"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$OUT/run.log"; }
stop() { log "STOP $*"; printf 'stopped: %s\n' "$*" > "$OUT/DONE"; exit 1; }
[ -f "$KEY_FILE" ] || stop "no key file"
rm -f "$OUT/DONE"
printf '%s\n' "$$" > "$OUT/driver.pid"
[ -f "$OUT/tasks.tsv" ] || printf 'task\texit\tstart\tend\tseconds\n' > "$OUT/tasks.tsv"
log "driver $$ starts: list $list, $(grep -c . "$list") cases"

# The server's own defaults, once per start (GET /props on the server's root), with the key from the mounted file.
docker run --rm --name "$PREFIX-props" "${labels[@]}" --cpu-shares "$CPU_SHARES" --network host \
  -v "$KEY_FILE:/run/model_key:ro" -v "$OUT:/out" -e MODEL_URL "$IMAGE" bash -c \
  'printf "Authorization: Bearer %s\n" "$(cat /run/model_key)" | curl -sS -m 60 -H @- -o /out/props.json "${MODEL_URL%/v1}/props"' \
  < /dev/null || log "props: not read"

while IFS=$'\t' read -r folder clone; do
  [ -n "$folder" ] || continue
  id=$(basename "$folder")
  if awk -F'\t' -v id="$id" '$1 == id && ($2 == 0 || $2 == 10) { found = 1 } END { exit !found }' "$OUT/tasks.tsv"; then
    log "$id: ended in an earlier start, skipped"
    continue
  fi
  if [ -e "$WORK/tasks/$folder/ticket.md" ] || [ -e "$WORK/tasks/$folder/statement.json" ]; then
    stop "$id: the case folder already holds a statement that this run did not write"
  fi
  bench=$(docker ps --format '{{.Names}}' | grep '^eab-' || true)
  [ -z "$bench" ] || stop "a bench run is up: $bench"
  free=$(df -B1 --output=avail / | tail -n 1 | tr -d ' ')
  [ "$free" -ge "$MIN_FREE" ] || stop "free space $free bytes"
  if [ -e "$OUT/$id" ]; then
    n=1
    while [ -e "$OUT/$id.earlier-$n" ]; do n=$((n + 1)); done
    mv "$OUT/$id" "$OUT/$id.earlier-$n" || stop "$id: earlier records could not be moved aside"
    log "$id: earlier records moved to $id.earlier-$n"
  fi
  mkdir -p "$OUT/$id"
  start=$(date -u +%FT%TZ)
  log "$id: start (free $free bytes)"
  docker run --rm --name "$PREFIX-$id" "${labels[@]}" --cpu-shares "$CPU_SHARES" --network host \
    -v "$KEY_FILE:/run/model_key:ro" -v "$WORK/tasks/$folder:/task" -v "$CLONES/$clone:/clone:ro" \
    -v "$TOOLS:/tools:ro" -v "$OUT/$id:/out" \
    -e MODEL_URL -e MODEL_KEY_FILE=/run/model_key -e MODEL -e WRITER_MODEL -e WRITER_FILE -e WRITER_PRESET \
    "$IMAGE" elixir -r /tools/statement.ex /tools/write_statement.exs /task /clone /out \
    > "$OUT/$id/stdout.log" 2>&1 < /dev/null
  rc=$?
  end=$(date -u +%FT%TZ)
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$rc" "$start" "$end" "$(($(date -d "$end" +%s) - $(date -d "$start" +%s)))" \
    >> "$OUT/tasks.tsv"
  log "$id: exit $rc"
  case $rc in
  0 | 10) ;;
  13) stop "$id: three server errors in a row" ;;
  14) stop "$id: the server was busy" ;;
  *) stop "$id: tool error $rc" ;;
  esac
done < "$list"
log "done"
printf 'done\n' > "$OUT/DONE"
