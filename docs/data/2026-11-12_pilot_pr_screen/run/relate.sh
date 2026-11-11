#!/usr/bin/env bash
# Step 3. Join the census row of each pull request with flatten_meta.sh's row, then find the later pull requests that
# name it (by number, or by closing the same issue; next 50 merged and 30 days), the reverts, and the counts this screen
# needs (see relate.awk).
#   CENSUS  the census folder (prs_<owner>__<name>.tsv[.gz])
#   WORK    folder with meta_<owner>__<name>.tsv (flatten_meta.sh's output); writes
#           $WORK/base_<slug>.tsv, pairs_<slug>.tsv, revcand_<slug>.tsv
set -euo pipefail
: "${CENSUS:?the census folder}"; : "${WORK:?work folder}"
here="$(cd "$(dirname "$0")" && pwd)"
for meta in "$WORK"/meta_*.tsv; do
  slug=$(basename "$meta" .tsv); slug=${slug#meta_}; repo="${slug/__//}"
  if [ -f "$CENSUS/prs_$slug.tsv.gz" ]; then cat_cmd=(gzip -dc "$CENSUS/prs_$slug.tsv.gz"); else cat_cmd=(cat "$CENSUS/prs_$slug.tsv"); fi
  [ "$("${cat_cmd[@]}" | tail -n +2 | wc -l)" = "$(wc -l < "$meta")" ] || { echo "$slug: census and meta row counts differ" >&2; exit 1; }
  paste <("${cat_cmd[@]}" | tail -n +2) "$meta" > "$WORK/joined_$slug.tsv"
  awk -f "$here/lib.awk" -f "$here/relate.awk" -v REPO="$repo" -v HAND="$here/reverts_by_hand.tsv" \
      -v OUT_BASE="$WORK/base_$slug.tsv" -v OUT_PAIRS="$WORK/pairs_$slug.tsv" -v OUT_REV="$WORK/revcand_$slug.tsv" \
      "$WORK/joined_$slug.tsv"
done
