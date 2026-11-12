#!/usr/bin/env bash
# scans.sh: the licence scan and the hold-out check (factory/tools/check_tasks.sh, unchanged) on checked tasks, one
# task at a time. One work folder serves every task, so the checked-out trees and the Hex metadata are fetched once;
# each task's tables are copied to their own folder after its run.
#   scans.sh cases   a temporary copy of the bench's cases folder BENCH_SRC in BENCH, without admission.json and
#                    README.md, as the earlier runs of the tools used it (read in place, never copied into a repository)
#   scans.sh run     check_tasks.sh on each task folder of TASKS named in IDS (default: all of them), one after another
#   scans.sh clean   delete BENCH, the work folder's trees, and every LOCAL_spans.json (the shared spans' text)
# Environment: SRC (the factory folder), TASKS (the folder of checked task folders), IDS (optional, space separated),
# CLONE (a clone of the project holding every starting and merge commit; blobs are fetched on demand), BENCH_SRC,
# BENCH, OUT (the scans' folder), LABELS (key=value[,key=value...] on every container).
# Writes OUT/work/ (check_tasks.sh's work folder), OUT/<id>/ (that task's tables: licence.*.tsv, locks.tsv, deps.tsv,
# holdout.*, LOCAL_spans.json), OUT/<id>.log, OUT/<id>.times (start and end), and one line per task to standard output:
# the id, the exit code, the licence result and the hold-out result.
set -euo pipefail
: "${OUT:?}" "${BENCH:?}"
step=${1:?cases|run|clean}
case $step in
cases)
  : "${BENCH_SRC:?}"
  [ ! -e "$BENCH" ] || { echo "$BENCH exists"; exit 1; }
  mkdir -p "$BENCH"
  tar -C "$BENCH_SRC" --exclude=admission.json --exclude=README.md -cf - . | tar -C "$BENCH" -xf -
  ls "$BENCH" | wc -l
  ;;
run)
  : "${SRC:?}" "${TASKS:?}" "${CLONE:?}" "${LABELS:?}"
  args=""
  IFS=, read -ra labels <<< "$LABELS"
  for l in "${labels[@]}"; do args="$args --label $l"; done
  W=$OUT/work
  mkdir -p "$W"
  ids=${IDS:-$(ls "$TASKS")}
  for id in $ids; do
    o=$OUT/$id
    rm -rf "$o"; mkdir -p "$o"
    echo "$(date -Is) start" > "$o.times"
    rm -f "$W"/licence.*.tsv "$W"/holdout.* "$W"/LOCAL_spans.json "$W"/locks.tsv "$W"/deps.tsv
    rc=0
    WORK=$W CLONES=$CLONE BENCH_CASES=$BENCH HEX_FETCH=1 DOCKER_RUN_ARGS="$args --cpu-shares 256" \
      LOCAL_SPANS=$W/LOCAL_spans.json "$SRC/tools/check_tasks.sh" "$TASKS/$id" > "$o.log" 2>&1 || rc=$?
    for f in licence.tasks.tsv licence.files.tsv licence.commits.tsv locks.tsv deps.tsv holdout.tasks.tsv \
      holdout.hits.tsv holdout.json LOCAL_spans.json revisions.tsv; do
      [ ! -e "$W/$f" ] || cp "$W/$f" "$o/"
    done
    echo "$(date -Is) end rc=$rc" >> "$o.times"
    lic=$(awk -F'\t' 'NR == 2 {print $8}' "$o/licence.tasks.tsv" 2>/dev/null || true)
    hold=$(awk -F'\t' 'NR == 2 {print $NF}' "$o/holdout.tasks.tsv" 2>/dev/null || true)
    echo "$id rc=$rc licence=${lic:--} holdout=${hold:--}"
  done
  ;;
clean)
  rm -rf "$BENCH" "$OUT/work/trees"
  rm -f "$OUT"/*/LOCAL_spans.json "$OUT/work/LOCAL_spans.json"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
