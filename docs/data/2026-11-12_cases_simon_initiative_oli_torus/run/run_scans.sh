#!/usr/bin/env bash
# run_scans.sh: the licence scan and the hold-out check (scans.sh) on the named checked tasks of this run, one task at
# a time, then the shared spans' text removed (it is for reading on the machine only), then a marker.
#   run_scans.sh <id> ...
# Environment: JOB (the job's folder: oli-torus.git, a full clone of the project), T (the run's folder: run/, src/,
# out/, logs/), WORK (the factory's work folder: tasks/), BENCH_CASES (the bench's cases/ folder, read in place).
# Writes T/out/scans/ (scans.sh's folders and scans.tsv), T/logs/scans_<time>.log and T/out/scans.done.
set -uo pipefail
: "${JOB:?}" "${T:?}" "${WORK:?}" "${BENCH_CASES:?}"
export SRC=$T/src DEST=$WORK/tasks/Simon-Initiative__oli-torus CLONE=$JOB/oli-torus.git BENCH_CASES OUT=$T/out/scans \
  LABELS=task-factory=1,task-factory-job=hb-olitorus
rm -f "$T/out/scans.done"
"$T/run/scans.sh" "$@" > "$T/logs/scans_$(date +%H%M%S).log" 2>&1
rc=$?
rm -f "$T"/out/scans/*/LOCAL_spans.json
echo "$rc $(date -Is)" > "$T/out/scans.done"
