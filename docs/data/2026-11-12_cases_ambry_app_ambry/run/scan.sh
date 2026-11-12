#!/usr/bin/env bash
# scan.sh: the licence scan and the hold-out check (factory/tools/check_tasks.sh, unchanged) on one checked task at a
# time, each in its own output folder, on the data-mining machine.
#   For each id: a copy of the checked task folder (DEST/<id>) goes to WORK/tasks/<id>, then check_tasks.sh runs on it
#   with OUT=WORK/<id>/ as its WORK. The bench's case files are copied once to a temporary folder without
#   admission.json and README.md (as job P6 did), read in place there, and deleted with the shared spans' text at the
#   end.
# Environment: SRC (the factory folder), DEST (the checked task folders), WORK (this step's folder), CLONES (git
# directories that hold the tasks' commits), BENCH_SRC (the bench's cases/ folder; only read), LABELS (key=value[,...] on
# every container), IMAGE (python:3.12-slim-bookworm), HEX_FETCH (1). Arguments: the task ids, in order.
# Writes WORK/<id>/ (check_tasks.sh's tables), WORK/<id>.log, WORK/<id>.times (start, end, seconds) and last
# WORK/scan.done (the exit codes).
set -uo pipefail
: "${SRC:?}" "${DEST:?}" "${WORK:?}" "${CLONES:?}" "${BENCH_SRC:?}" "${LABELS:?}"
[ $# -gt 0 ] || { echo "usage: $0 ID [...]" >&2; exit 2; }
mkdir -p "$WORK/tasks"
BENCH=$WORK/bench_cases
rm -rf "$BENCH" && mkdir -p "$BENCH"
tar -C "$BENCH_SRC" --exclude=admission.json --exclude=README.md -cf - . | tar -C "$BENCH" -xf -
export CLONES BENCH_CASES=$BENCH HEX_FETCH=${HEX_FETCH:-1} IMAGE=${IMAGE:-python:3.12-slim-bookworm}
export DOCKER_RUN_ARGS="--label ${LABELS//,/ --label } --cpu-shares 256"
codes=()
for id in "$@"; do
  rm -rf "$WORK/tasks/$id" "$WORK/$id"
  cp -a "$DEST/$id" "$WORK/tasks/$id"
  t0=$(date +%s); s=$(date -Is)
  o=$WORK/$id
  mkdir -p "$o"
  WORK=$o LOCAL_SPANS=$o/LOCAL_spans.json "$SRC/tools/check_tasks.sh" "$WORK/tasks/$id" > "$WORK/$id.log" 2>&1
  rc=$?
  printf '%s\t%s\t%s\t%s\n' "$s" "$(date -Is)" "$(($(date +%s) - t0))" "$rc" > "$WORK/$id.times"
  # the shared spans' text is for reading on this machine only; kept as LOCAL_spans.json until read, then deleted
  # by hand (KEEP_SPANS=0 deletes it at once)
  [ "${KEEP_SPANS:-0}" = 1 ] || rm -f "$o/LOCAL_spans.json"
  codes+=("$id=$rc")
done
rm -rf "$BENCH"
echo "${codes[*]} $(date -Is)" > "$WORK/scan.done"
