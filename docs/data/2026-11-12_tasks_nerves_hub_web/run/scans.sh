#!/usr/bin/env bash
# scans.sh: the licence scan and the hold-out check (factory/tools/check_tasks.sh) on the checked tasks, on the
# data-mining machine. The bench's case files are copied without admission.json into SCAN/bench_cases for the run, read
# in place, and deleted afterwards with the shared spans' text (LOCAL_spans.json); nothing of them leaves the machine.
# No Hex metadata is fetched (HEX_FETCH unset): the dependency list then reads "not fetched", and no task's verdict
# depends on it.
# Environment: SRC (the factory folder), TASKS (the folder of checked task folders), CLONES (git directories with the
# tasks' commits), BENCH (the bench's cases/ folder), SCAN (a new output folder), IMAGE (a Python 3.9+ image),
# LABELS (key=value, space separated: one --label each), CPU_SHARES (256).
# Writes SCAN/scan.log and the tool's tables in SCAN (licence.tasks.tsv, licence.files.tsv, holdout.tasks.tsv, ...),
# and last SCAN/scans.done (the exit code).
set -uo pipefail
: "${SRC:?}" "${TASKS:?}" "${CLONES:?}" "${BENCH:?}" "${SCAN:?}" "${IMAGE:?}" "${LABELS:?}"
mkdir -p "$SCAN"
rm -f "$SCAN/scans.done"
args="--cpu-shares ${CPU_SHARES:-256}"
for l in $LABELS; do args="$args --label $l"; done
rm -rf "$SCAN/bench_cases"
mkdir -p "$SCAN/bench_cases"
(cd "$BENCH" && tar --exclude='admission.json' -cf - .) | (cd "$SCAN/bench_cases" && tar -xf -)
rc=0
{
  date -Is
  WORK=$SCAN CLONES=$CLONES BENCH_CASES=$SCAN/bench_cases IMAGE=$IMAGE DOCKER_RUN_ARGS="$args" \
    LOCAL_SPANS=$SCAN/LOCAL_spans.json "$SRC/tools/check_tasks.sh" "$TASKS" || rc=$?
  date -Is
} > "$SCAN/scan.log" 2>&1
rm -rf "$SCAN/bench_cases" "$SCAN/LOCAL_spans.json"
echo "$rc" > "$SCAN/scans.done"
