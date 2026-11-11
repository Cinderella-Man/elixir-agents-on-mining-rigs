#!/usr/bin/env bash
# Step 6. The verdict of every merged pull request (verdict.awk), one file per repository, and the table of named pairs.
#   WORK  folder with base_<slug>.tsv and tested_<slug>.tsv (relate.sh and repair.sh); writes $WORK/pairstat_<slug>.tsv
#   OUT   the committed folder; writes screen_<slug>.tsv (gzip if over 1 MB) and pairs.tsv
set -euo pipefail
: "${WORK:?work folder}"; : "${OUT:?output folder}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
rm -f "$OUT"/screen_*.tsv "$OUT"/screen_*.tsv.gz "$OUT/pairs.tsv"
printf 'repo\tearlier\tlater\troute\tdays\trank_gap\tstatus\tshared_files\tpatch_missing\tlines_matched\tlines_same_place\trepaired\n' > "$OUT/pairs.tsv"
for base in "$WORK"/base_*.tsv; do
  slug=$(basename "$base" .tsv); slug=${slug#base_}; repo="${slug/__//}"
  awk -f "$here/lib.awk" -f "$here/verdict.awk" -v REPO="$repo" -v BASE="$base" -v OUT_PAIRSTAT="$WORK/pairstat_$slug.tsv" \
      "$base" "$WORK/tested_$slug.tsv" > "$OUT/screen_$slug.tsv"
  awk -v repo="$repo" 'BEGIN { FS = OFS = "\t" } { print repo, $0 }' "$WORK/tested_$slug.tsv" >> "$OUT/pairs.tsv"
  if [ "$(du -k "$OUT/screen_$slug.tsv" | cut -f1)" -gt 1024 ]; then gzip -n -f "$OUT/screen_$slug.tsv"; fi
  echo "$repo: $(( $(gzip -dcf "$OUT"/screen_$slug.tsv* | wc -l) - 1 )) rows"
done
