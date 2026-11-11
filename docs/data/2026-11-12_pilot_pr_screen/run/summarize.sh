#!/usr/bin/env bash
# Step 7. summary.tsv (one row per repository and a Together row, every column named in summarize.awk) and
# candidates_first.tsv (per repository, the first 60 candidates to try: 2 to 5 code files, no migration, no assets/,
# newest first).
#   OUT  the committed folder with screen_<slug>.tsv[.gz] and pairs.tsv (verdict.sh's output)
set -euo pipefail
: "${OUT:?the committed folder}"
here="$(cd "$(dirname "$0")" && pwd)"
{
  for f in "$OUT"/screen_*.tsv "$OUT"/screen_*.tsv.gz; do
    [ -e "$f" ] || continue
    slug=$(basename "$f"); slug=${slug#screen_}; slug=${slug%.gz}; slug=${slug%.tsv}; repo="${slug/__//}"
    gzip -dcf "$f" | awk -v repo="$repo" 'BEGIN { FS = OFS = "\t" } NR > 1 { print "S", repo, $0 }'
  done
  awk 'BEGIN { FS = OFS = "\t" } NR > 1 { print "P", $0 }' "$OUT/pairs.tsv"
} | awk -f "$here/summarize.awk" > "$OUT/summary.tsv"
printf 'repo\trank\tnumber\tmerged_at\tcode_files\ttest_files\tai_tool\trepair_of\tnamed_by\ttouched_again_tests\tissue_linked\tbase_main\n' > "$OUT/candidates_first.tsv"
for f in "$OUT"/screen_*.tsv "$OUT"/screen_*.tsv.gz; do
  [ -e "$f" ] || continue
  slug=$(basename "$f"); slug=${slug#screen_}; slug=${slug%.gz}; slug=${slug%.tsv}; repo="${slug/__//}"
  gzip -dcf "$f" | awk -F'\t' -v OFS='\t' 'NR > 1 && $4 == "candidate" && $8 == "2-5" && $11 == 0 && $12 == 0 { print $2, $1, $9, $10, $13, $18, $15, ($20 != "-") , $21, $23 }' \
    | sort -t$'\t' -k1,1r -k2,2nr | head -60 \
    | awk -F'\t' -v OFS='\t' -v repo="$repo" '{ print repo, NR, $2, $1, $3, $4, $5, $6, $7, $8, $9, $10 }' >> "$OUT/candidates_first.tsv"
done
