#!/usr/bin/env bash
# scans.sh: the licence scan and the hold-out check (factory/tools/check_tasks.sh) on each checked task of this job,
# one task at a time, each with its own output folder, on the data-mining machine.
#   scans.sh <id> ...
# Environment: SRC (the factory folder), DEST (the folder of the checked task folders), CLONE (a full clone of the
# project), BENCH_CASES (the bench's cases/ folder, read in place, never copied), OUT (the scans' folder), LABELS
# (key=value[,key=value...]: on every container the scan starts). Hex metadata is fetched (HEX_FETCH=1).
# Writes OUT/<id>/ (check_tasks.sh's tables), OUT/<id>.log, OUT/<id>.done (the exit code and the time) and, again after
# each task, OUT/scans.tsv: id, licence_result, licence_families, files_touched, files_passing, failing (the scan's
# reasons), holdout_result, name_hits, seconds.
# The shared spans' text (LOCAL_spans.json) stays in OUT/<id>/ for reading on the machine and is never published.
set -euo pipefail
: "${SRC:?}" "${DEST:?}" "${CLONE:?}" "${BENCH_CASES:?}" "${OUT:?}" "${LABELS:?}"
[ $# -gt 0 ] || { echo "usage: $0 <id> ..." >&2; exit 2; }
args=""
IFS=, read -ra labels <<< "$LABELS"
for l in "${labels[@]}"; do args="$args --label $l"; done
mkdir -p "$OUT"
for id in "$@"; do
  w=$OUT/$id
  rm -rf "$w" "$OUT/$id.done"
  mkdir -p "$w"
  t0=$(date +%s)
  rc=0
  WORK=$w CLONES=$CLONE BENCH_CASES=$BENCH_CASES HEX_FETCH=1 LOCAL_SPANS=$w/LOCAL_spans.json \
    DOCKER_RUN_ARGS="$args --cpu-shares 256" "$SRC/tools/check_tasks.sh" "$DEST/$id" > "$OUT/$id.log" 2>&1 || rc=$?
  echo "$rc $(date -Is) $(($(date +%s) - t0))" > "$OUT/$id.done"
done
{
  printf 'id\tlicence_result\tlicence_families\tfiles_touched\tfiles_passing\tfailing\tholdout_result\tname_hits\tseconds\n'
  for d in "$OUT"/*.done; do
    id=$(basename "$d" .done)
    l=$OUT/$id/licence.tasks.tsv h=$OUT/$id/holdout.tasks.tsv
    lic=$( [ -f "$l" ] && awk -F'\t' 'NR == 2 {print $8 "\t" $4 "\t" $6 "\t" $7 "\t" ($9 == "" ? "-" : $9)}' "$l" || printf 'missing\t-\t-\t-\t-')
    hold=$( [ -f "$h" ] && awk -F'\t' 'NR == 1 {for (i = 1; i <= NF; i++) c[$i] = i} NR == 2 {print $c["holdout_result"] "\t" $c["name_hits"]}' "$h" || printf 'missing\t-')
    printf '%s\t%s\t%s\t%s\n' "$id" "$lic" "$hold" "$(cut -d' ' -f3 "$d")"
  done
} > "$OUT/scans.tsv"
cat "$OUT/scans.tsv"
