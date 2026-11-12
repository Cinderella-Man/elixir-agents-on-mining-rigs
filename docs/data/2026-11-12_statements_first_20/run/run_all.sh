#!/usr/bin/env bash
# run_all.sh: the statements of a list of tasks, one task at a time, on the data-mining machine (job P7, E9, E81).
# Each task runs factory/tools/statements/write_statement.exs in its own tooling container; the next starts when it
# has ended. Before each task: no bench run container is up (a name starting with "eab-") and the root file system
# has at least MIN_FREE bytes free; otherwise the run stops. It also stops on a task that ends with three server
# errors in a row (13), a busy server (14) or a tool error (any code but 0 and 10).
# Environment:
#   WORK        the factory's work folder (task folders in WORK/tasks)
#   TOOLS       the folder holding statement.ex, write_statement.exs and instruction.md
#   CLONES      a folder of bare Git clones holding the tasks' commits
#   OUT         where the records go: OUT/<task id>/..., OUT/tasks.tsv, OUT/run.log, OUT/props.json, OUT/DONE
#   MODEL_URL   the server's OpenAI-style base URL (ending in /v1), reached from the containers (host network)
#   KEY_FILE    the file that holds the server's key (mounted read only; never printed)
#   MODEL       the served model's name
#   WRITER_MODEL, WRITER_FILE, WRITER_PRESET   the writer's id for statement.json
#   IMAGE       the tooling image; LABEL (key=value); CPU_SHARES (256); MIN_FREE (700000000000)
# Usage: run_all.sh <task list: "<folder under WORK/tasks><TAB><clone under CLONES>" per line>
set -uo pipefail
: "${WORK:?}" "${TOOLS:?}" "${CLONES:?}" "${OUT:?}" "${MODEL_URL:?}" "${KEY_FILE:?}" "${MODEL:?}" "${IMAGE:?}"
: "${WRITER_MODEL:?}" "${WRITER_FILE:?}" "${WRITER_PRESET:?}" "${LABEL:?LABEL=<key=value>}"
CPU_SHARES=${CPU_SHARES:-256}
MIN_FREE=${MIN_FREE:-700000000000}
list=${1:?task list}
mkdir -p "$OUT"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$OUT/run.log"; }
stop() { log "STOP $*"; printf 'stopped: %s\n' "$*" > "$OUT/DONE"; exit 1; }
[ -f "$KEY_FILE" ] || stop "no key file"
rm -f "$OUT/DONE"
[ -f "$OUT/tasks.tsv" ] || printf 'task\texit\tstart\tend\tseconds\n' > "$OUT/tasks.tsv"

# The server's own defaults, once (GET /props on the server's root), with the key from the mounted file.
docker run --rm --name etf-statements-props --label "$LABEL" --cpu-shares "$CPU_SHARES" --network host \
  -v "$KEY_FILE:/run/model_key:ro" -v "$OUT:/out" -e MODEL_URL "$IMAGE" bash -c \
  'printf "Authorization: Bearer %s\n" "$(cat /run/model_key)" | curl -sS -m 60 -H @- -o /out/props.json "${MODEL_URL%/v1}/props"' ||
  log "props: not read"

while IFS=$'\t' read -r folder clone; do
  [ -n "$folder" ] || continue
  id=$(basename "$folder")
  if awk -F'\t' -v id="$id" '$1 == id && $2 == 0 { found = 1 } END { exit !found }' "$OUT/tasks.tsv"; then
    log "$id: has its statement, skipped"
    continue
  fi
  bench=$(docker ps --format '{{.Names}}' | grep '^eab-' || true)
  [ -z "$bench" ] || stop "a bench run is up: $bench"
  free=$(df -B1 --output=avail / | tail -1 | tr -d ' ')
  [ "$free" -ge "$MIN_FREE" ] || stop "free space $free bytes"
  rm -rf "${OUT:?}/$id"
  mkdir -p "$OUT/$id"
  start=$(date -u +%FT%TZ)
  log "$id: start (free $free bytes)"
  docker run --rm --name "etf-statements-$id" --label "$LABEL" --cpu-shares "$CPU_SHARES" --network host \
    -v "$KEY_FILE:/run/model_key:ro" -v "$WORK/tasks/$folder:/task" -v "$CLONES/$clone:/clone:ro" \
    -v "$TOOLS:/tools:ro" -v "$OUT/$id:/out" \
    -e MODEL_URL -e MODEL_KEY_FILE=/run/model_key -e MODEL -e WRITER_MODEL -e WRITER_FILE -e WRITER_PRESET \
    "$IMAGE" elixir -r /tools/statement.ex /tools/write_statement.exs /task /clone /out \
    > "$OUT/$id/stdout.log" 2>&1 < /dev/null
  rc=$?
  end=$(date -u +%FT%TZ)
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$rc" "$start" "$end" "$(( $(date -d "$end" +%s) - $(date -d "$start" +%s) ))" \
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
