#!/usr/bin/env bash
# check_one.sh: import one task folder into a running controller and check it, through the factory's own entry points
# (bin/factoryctl import, check, job), timing each call. `import` takes a folder of task folders, so the one task is
# first copied to CTL/data/import/<id>/<id>. Waits for the check's job.json to leave "running".
# Environment: CTL, NAME, SRC (as for proofs.sh), TASK_DIR (the task folder to import, a path the controller mounts),
# OUT (where the answers go).
# Writes OUT/import.json, OUT/check.json (the job id), OUT/job.json (the job's record at the end), OUT/times.tsv
# (step, start, end, seconds).
set -euo pipefail
: "${CTL:?}" "${NAME:?}" "${SRC:?}" "${TASK_DIR:?}" "${OUT:?}"
ctl() { NAME=$NAME "$SRC/bin/factoryctl" "$@"; }
mkdir -p "$OUT"
printf 'step\tstart\tend\tseconds\n' > "$OUT/times.tsv"
stamp() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(( $(date -d "$3" +%s) - $(date -d "$2" +%s) ))" >> "$OUT/times.tsv"; }
id=$(basename "$TASK_DIR")
stage="$CTL/data/import/$id"
rm -rf "$stage"
mkdir -p "$stage"
cp -a "$TASK_DIR" "$stage/$id"
t0=$(date -Is); ctl import "$stage" | tee "$OUT/import.json"; stamp import "$t0" "$(date -Is)"
jq -e --arg id "$id" '.ok | any(.id == $id and (.result == "imported" or .result == "unchanged"))' "$OUT/import.json" > /dev/null ||
  { echo "import did not take $id"; exit 1; }
t0=$(date -Is); ctl check --concurrency 1 "$id" | tee "$OUT/check.json"
job=$(jq -er '.ok' "$OUT/check.json") || { echo "check refused"; exit 1; }
until [ -e "$CTL/data/factory/jobs/$job/job.json" ] && [ "$(jq -r '.status' "$CTL/data/factory/jobs/$job/job.json")" != running ]; do sleep 15; done
stamp check "$t0" "$(date -Is)"
ctl job "$job" > "$OUT/job.json"
jq -c '{status, counts}' "$CTL/data/factory/jobs/$job/job.json"
