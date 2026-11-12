#!/usr/bin/env bash
# run_scans.sh: the licence scan and the hold-out check (scans.sh run, then scans.sh table) on this job's checked
# cases, one task at a time; a case already scanned is not scanned again. Then the shared spans' text is removed (it
# is for reading on the machine only), then a marker.
# Environment: JOB (this job's folder: run/, src/ the factory folder), CLONE (a bare clone of the project), DEST (the
# folder of checked task folders), IDS (one task id per line), BENCH_CASES (the bench's cases/ folder, read in place,
# never copied), LABELS (key=value[,key=value...] for every container the scans start).
# Writes JOB/out/scans/ (scans.sh's folders and scans.tsv), JOB/logs/scans_<time>.log and JOB/out/scans.done.
set -uo pipefail
: "${JOB:?}" "${CLONE:?}" "${DEST:?}" "${IDS:?}" "${BENCH_CASES:?}" "${LABELS:?}"
export SRC=$JOB/src DEST IDS BENCH_CASES LABELS CLONES=$CLONE OUT=$JOB/out/scans
mkdir -p "$OUT" "$JOB/logs"
rm -f "$JOB/out/scans.done"
log=$JOB/logs/scans_$(date +%H%M%S).log
"$JOB/run/scans.sh" run > "$log" 2>&1
rc=$?
"$JOB/run/scans.sh" table >> "$log" 2>&1
rm -f "$OUT"/*/LOCAL_spans.json
echo "$rc $(date -Is)" > "$JOB/out/scans.done"
