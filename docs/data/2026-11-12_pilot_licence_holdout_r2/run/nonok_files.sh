#!/usr/bin/env bash
# licence.nonok.tsv: every file the per-file licence scan did not pass (verdict other than ok, ok:notice, ok:licence-file)
# in any of a run's trees, with the number of trees it appears in. Binary files are grouped by extension and the
# vendored heroicons folder is one row. Reads the scan tables that check_tasks.sh left in WORK/trees/.
#   WORK  the folder of a check_tasks.sh run
set -euo pipefail
: "${WORK:?}"
cd "$WORK/trees"
for f in *.scan.tsv; do
  c=${f%.scan.tsv}
  awk -F'\t' -v c="$c" 'NR>1 && $8 !~ /^ok/ {
      p=$1; v=$8
      if (p ~ /^assets\/vendor\/heroicons\//) p="assets/vendor/heroicons/ (all files in the folder)"
      else if (v=="exclude:binary") {n=split(p,a,"."); p="*." a[n] " (binary files)"}
      print v "\t" p "\t" c }' "$f" | sort -u
done | awk -F'\t' '{k=$1"\t"$2; n[k]++} END{for(k in n) print k"\t"n[k]}' | sort | \
  { printf 'verdict\tpath\ttrees\n'; cat; } > "$WORK/licence.nonok.tsv"
cat "$WORK/licence.nonok.tsv"
