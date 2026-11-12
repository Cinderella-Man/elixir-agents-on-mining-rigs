#!/usr/bin/env bash
# pub.sh: the data folder's tables from this job's output, on the data-mining machine.
#   tasks_jola_dev.tsv   tables.sh's tasks table with this job's own images (tasks_own.tsv), one line per try
#   counts.tsv, checked.tsv, kind_rule.tsv   as made by tables.sh, checked.sh and kind_rule.sh
#   scans.tsv          scans.sh's table of the two scans per case
#   licence_root.tsv   per case: the scan's licence columns (licence.tasks.tsv), the root licence and its proof
#   licence_files.tsv  per case and touched file: the patches that touch it, the per-file verdict at the starting and
#                      the merge commit, the result (licence.files.tsv)
#   holdout_tasks.tsv  per case: the hold-out check's columns (holdout.tasks.tsv)
#   deps_flagged.tsv   the locked dependencies whose licence class is not plainly "allowed", with the number of cases
#                      that lock each (deps.tsv of every case)
# Environment: OUT (all.sh's output folder, with tables/ and scans/), DEST (where to write).
set -euo pipefail
: "${OUT:?}" "${DEST:?}"
mkdir -p "$DEST"
cp "$OUT/tables/tasks_own.tsv" "$DEST/tasks_jola_dev.tsv"
cp "$OUT/tables/counts.tsv" "$OUT/tables/checked.tsv" "$OUT/tables/kind_rule.tsv" "$OUT/scans/scans.tsv" "$DEST/"
cat_tables() { # $1 file name in each case's scan folder: the header once, then every case's rows
  local first=1 f
  for f in $(ls "$OUT"/scans/*/"$1" | sort -t- -k3 -nr); do
    if [ $first = 1 ]; then cat "$f"; first=0; else tail -n +2 "$f"; fi
  done
}
cat_tables licence.tasks.tsv > "$DEST/licence_root.tsv"
cat_tables licence.files.tsv > "$DEST/licence_files.tsv"
cat_tables holdout.tasks.tsv > "$DEST/holdout_tasks.tsv"
{
  printf 'kind\tpackage\tversion\tlicences\tclass\tcases\n'
  for f in "$OUT"/scans/*/deps.tsv; do
    awk -F'\t' 'NR == 1 {for (i = 1; i <= NF; i++) c[$i] = i; next}
      $c["class"] != "allowed" {print $c["kind"] "\t" $c["package"] "\t" $c["version"] "\t" $c["licences"] "\t" $c["class"]}' "$f"
  done | sort | uniq -c | sort -k1,1nr -k3 | awk '{n = $1; sub(/^ *[0-9]+ /, ""); print $0 "\t" n}'
} > "$DEST/deps_flagged.tsv"
wc -l "$DEST"/*.tsv
