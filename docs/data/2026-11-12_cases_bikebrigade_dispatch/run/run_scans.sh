#!/usr/bin/env bash
# run_scans.sh: the licence scan and the hold-out check (scans.sh) on the named checked tasks of this job, one task at
# a time, then the shared spans' text removed (it is for reading on the machine only), then a marker.
#   run_scans.sh <id> ...
# Environment: JOB (this job's folder: run/, src/, dispatch.git (a full clone of the project), out/, logs/), WORK (the
# factory's work folder: tasks/), BENCH_CASES (the bench's cases/ folder, read in place).
# Writes JOB/out/scans/ (scans.sh's folders and scans.tsv), JOB/logs/scans_<time>.log and JOB/out/scans.done.
set -uo pipefail
: "${JOB:?}" "${WORK:?}" "${BENCH_CASES:?}"
export SRC=$JOB/src DEST=$WORK/tasks/bikebrigade__dispatch CLONE=$JOB/dispatch.git BENCH_CASES OUT=$JOB/out/scans \
  LABELS=task-factory=1,task-factory-job=hb-dispatch
mkdir -p "$JOB/logs"
rm -f "$JOB/out/scans.done"
"$JOB/run/scans.sh" "$@" > "$JOB/logs/scans_$(date +%H%M%S).log" 2>&1
rc=$?
rm -f "$JOB"/out/scans/*/LOCAL_spans.json
echo "$rc $(date -Is)" > "$JOB/out/scans.done"
