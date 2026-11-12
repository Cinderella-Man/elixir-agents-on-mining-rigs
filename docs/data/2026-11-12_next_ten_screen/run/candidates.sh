#!/usr/bin/env bash
# The candidates of every screen table, with the census's merge commit: slug, number, merged_at, merge_commit.
#   CENSUS  the census folder (prs_<slug>.tsv.gz)     SCREEN  the folder with screen_<slug>.tsv[.gz]     (stdout)
set -euo pipefail
: "${CENSUS:?}"; : "${SCREEN:?}"
for f in "$SCREEN"/screen_*.tsv "$SCREEN"/screen_*.tsv.gz; do
  [ -e "$f" ] || continue
  slug=$(basename "$f"); slug=${slug#screen_}; slug=${slug%.gz}; slug=${slug%.tsv}
  [ -f "$CENSUS/prs_$slug.tsv.gz" ] && cen=(gzip -dc "$CENSUS/prs_$slug.tsv.gz") || cen=(cat "$CENSUS/prs_$slug.tsv")
  join -t$'\t' -j1 \
    <("${cen[@]}" | awk -F'\t' -v OFS='\t' 'NR > 1 { print $1, $2, $10 }' | sort -t$'\t' -k1,1) \
    <(gzip -dcf "$f" | awk -F'\t' -v OFS='\t' 'NR > 1 && $4 == "candidate" { print $1 }' | sort -t$'\t' -k1,1) \
    | awk -F'\t' -v OFS='\t' -v slug="$slug" '{ print slug, $1, $2, $3 }' | sort -t$'\t' -k2,2n
done
