#!/usr/bin/env bash
# run_scans.sh: the licence scan and the hold-out check (scans.sh) on the named checked tasks, one task at a time, then
# the shared spans' text removed (it is for reading on the machine only), then a marker.
#   run_scans.sh <id> ...
# Environment: JOB (this job's folder: run/, src/, out/, logs/, backend.git, a full clone of the project), WORK (the
# factory's work folder: tasks/), BENCH_CASES (the bench's cases/ folder, read in place), JOB_LABEL (key=value: on
# every container the scans start, beside task-factory=1).
# Writes JOB/out/scans/ (scans.sh's folders and scans.tsv), JOB/logs/scans_<time>.log and JOB/out/scans.done.
set -uo pipefail
: "${JOB:?}" "${WORK:?}" "${BENCH_CASES:?}" "${JOB_LABEL:?}"
export SRC=$JOB/src DEST=$WORK/tasks/source-academy__backend CLONE=$JOB/backend.git BENCH_CASES OUT=$JOB/out/scans \
  LABELS=task-factory=1,$JOB_LABEL
rm -f "$JOB/out/scans.done"
"$JOB/run/scans.sh" "$@" > "$JOB/logs/scans_$(date +%H%M%S).log" 2>&1
rc=$?
rm -f "$JOB"/out/scans/*/LOCAL_spans.json
echo "$rc $(date -Is)" > "$JOB/out/scans.done"
