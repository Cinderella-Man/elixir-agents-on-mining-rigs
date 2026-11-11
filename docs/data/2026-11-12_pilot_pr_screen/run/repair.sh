#!/usr/bin/env bash
# Step 5. For the named pairs relate.sh found: write the list of pull requests whose patches are needed, fetch them
# (fetch_patches.sh), cut each patch into its added and removed lines, and test every pair (repair.awk).
#   WORK    folder with pairs_<slug>.tsv and base_<slug>.tsv (relate.sh's output); writes need_, files_, lines_ and
#           tested_<slug>.tsv there
#   RAW     folder for the raw patches (not committed)
#   NEED_SHARED  1 fetches only pairs whose pull requests change a common code or test path (default 0: every pair
#                where both pull requests change code or tests)
#   FETCH   0 reuses the patches already in $RAW (default 1)
set -euo pipefail
: "${WORK:?work folder}"; : "${RAW:?raw folder}"
here="$(cd "$(dirname "$0")" && pwd)"
NEED_SHARED="${NEED_SHARED:-0}"
for pairs in "$WORK"/pairs_*.tsv; do
  slug=$(basename "$pairs" .tsv); slug=${slug#pairs_}
  # pairs that are not a revert, where both pull requests change code or tests (and, with NEED_SHARED=1, a common path)
  awk -F'\t' -v S="$NEED_SHARED" '$6 == 0 && $8 > 0 && $9 > 0 && (S == 0 || $7 > 0) { print $1; print $2 }' "$pairs" | sort -n -u > "$WORK/need_$slug.txt"
  echo "$slug: $(wc -l < "$pairs") named pairs, $(wc -l < "$WORK/need_$slug.txt") pull requests need patches"
done
if [ "${FETCH:-1}" = 1 ]; then RAW="$RAW" WORK="$WORK" "$here/fetch_patches.sh"; fi
for pairs in "$WORK"/pairs_*.tsv; do
  slug=$(basename "$pairs" .tsv); slug=${slug#pairs_}
  dir="$RAW/patches/$slug"
  files=()
  while read -r n; do files+=("$dir/$n.json"); done < "$WORK/need_$slug.txt"
  if [ "${#files[@]}" -gt 0 ]; then
    jq -r -f "$here/files.jq" "${files[@]}" > "$WORK/files_$slug.tsv"
    jq -r -f "$here/lines.jq" "${files[@]}" > "$WORK/lines_$slug.tsv"
  else : > "$WORK/files_$slug.tsv"; : > "$WORK/lines_$slug.tsv"; fi
  awk -f "$here/repair.awk" -v FILES="$WORK/files_$slug.tsv" -v LINES="$WORK/lines_$slug.tsv" -v PAIRS="$pairs" \
      "$WORK/files_$slug.tsv" "$WORK/lines_$slug.tsv" "$pairs" > "$WORK/tested_$slug.tsv"
  echo "$slug: $(wc -l < "$WORK/tested_$slug.tsv") pairs, tested $(awk -F'\t' '$6 == "tested"' "$WORK/tested_$slug.tsv" | wc -l), repaired $(awk -F'\t' '$11 == 1' "$WORK/tested_$slug.tsv" | wc -l)"
done
