#!/usr/bin/env bash
# How much the shortest line that counts (MINLEN, default 12 characters) changes the number of repaired pairs: the same
# test as repair.sh, re-run on the lines it already extracted. Writes $OUT/sensitivity.tsv.
#   WORK  folder with files_, lines_ and pairs_<slug>.tsv (repair.sh's and relate.sh's output)
#   OUT   the committed folder
set -euo pipefail
: "${WORK:?work folder}"; : "${OUT:?output folder}"
here="$(cd "$(dirname "$0")" && pwd)"
{
  printf 'min_line_length\trepo\tpairs_tested\tpairs_repaired\tpairs_repaired_same_place\n'
  for L in 8 12 16 20 30; do
    for pairs in "$WORK"/pairs_*.tsv; do
      slug=$(basename "$pairs" .tsv); slug=${slug#pairs_}; repo="${slug/__//}"
      awk -f "$here/repair.awk" -v MINLEN="$L" -v FILES="$WORK/files_$slug.tsv" -v LINES="$WORK/lines_$slug.tsv" -v PAIRS="$pairs" \
          "$WORK/files_$slug.tsv" "$WORK/lines_$slug.tsv" "$pairs" \
        | awk -F'\t' -v L="$L" -v repo="$repo" -v OFS='\t' '$6 == "tested" { t++; if ($11 == 1) r++; if ($11 == 1 && $10 >= 1) s++ } END { print L, repo, t + 0, r + 0, s + 0 }'
    done
  done
} > "$OUT/sensitivity.tsv"
