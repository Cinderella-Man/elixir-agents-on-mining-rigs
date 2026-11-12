#!/usr/bin/env bash
# scans.sh: the licence scan and the hold-out check (factory/tools/check_tasks.sh) on each checked task of the job,
# one task at a time, each into its own folder, then one table of the verdicts.
#   scans.sh run     every task folder in DEST (the checked tasks), in the order of IDS (one id per line), into
#                    OUT/<id>/; a task whose OUT/<id>/done exists is not run again
#   scans.sh table   OUT/scans.tsv: per task, the licence scan's columns (licence.tasks.tsv), the hold-out check's
#                    (holdout.tasks.tsv: name hits, spans of 8 and 12 words and those left to read, the result), and
#                    the locked dependencies counted by licence class (deps.tsv)
# Environment: SRC (the factory folder), DEST (the folder of checked task folders), IDS, OUT, CLONES (git directories
# that hold the tasks' commits), BENCH_CASES (a temporary copy of the bench's cases/ folder, without admission.json;
# read in place, never copied into a repository), LABELS (key=value[,key=value...] for every container).
set -euo pipefail
: "${SRC:?}" "${DEST:?}" "${IDS:?}" "${OUT:?}"
step=${1:?run|table}
case $step in
run)
  : "${CLONES:?}" "${BENCH_CASES:?}" "${LABELS:?}"
  args="--cpu-shares 256"
  IFS=, read -ra labels <<< "$LABELS"
  for l in "${labels[@]}"; do args="$args --label $l"; done
  while read -r id; do
    [ -n "$id" ] || continue
    o=$OUT/$id
    [ ! -e "$o/done" ] || continue
    [ -d "$DEST/$id" ] || { echo "$(date -Is) $id: no task folder"; continue; }
    mkdir -p "$o"
    echo "$(date -Is) start $id load $(cut -d' ' -f1 /proc/loadavg)"
    rc=0
    WORK=$o CLONES=$CLONES BENCH_CASES=$BENCH_CASES HEX_FETCH=1 DOCKER_RUN_ARGS=$args \
      LOCAL_SPANS=$o/LOCAL_spans.json "$SRC/tools/check_tasks.sh" "$DEST/$id" > "$o/scan.log" 2>&1 || rc=$?
    echo "$rc $(date -Is)" > "$o/done"
    echo "$(date -Is) end $id rc $rc load $(cut -d' ' -f1 /proc/loadavg)"
  done < "$IDS"
  ;;
table)
  printf 'id\tlicence_file\tlicence_families\tfiles_touched\tfiles_passing\tlicence_result\tfailing\tname_hits\tspans8\tspans8_to_read\tspans12\tspans12_to_read\tholdout_result\tdeps_classes\tscan_rc\n' > "$OUT/scans.tsv"
  while read -r id; do
    [ -n "$id" ] || continue
    o=$OUT/$id
    [ -e "$o/done" ] || continue
    # the named columns of a table's first data row; "-" for a missing table or column
    cols() { local f=$1; shift; awk -F'\t' -v want="$*" 'NR == 1 {n = split(want, w, " "); for (i = 1; i <= NF; i++) k[$i] = i; next}
      NR == 2 {for (j = 1; j <= n; j++) {v = (w[j] in k) ? $(k[w[j]]) : "-"; printf "%s%s", (j > 1 ? "\t" : ""), (v == "" ? "-" : v)}; print ""; exit}' "$f" 2>/dev/null; }
    lic=$(cols "$o/licence.tasks.tsv" licence_file licence_families files_touched files_passing licence_result failing)
    hold=$(cols "$o/holdout.tasks.tsv" name_hits spans8 spans8_to_read spans12 spans12_to_read holdout_result)
    deps=$(awk -F'\t' 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == "class") k = i; next} k {c[$k]++} END {s = ""; for (x in c) s = s (s ? "; " : "") x "=" c[x]; print (s ? s : "-")}' "$o/deps.tsv" 2>/dev/null)
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "${lic:--	-	-	-	-	-}" "${hold:--	-	-	-	-	-}" "${deps:--}" "$(cut -d' ' -f1 "$o/done")" >> "$OUT/scans.tsv"
  done < "$IDS"
  cat "$OUT/scans.tsv"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
