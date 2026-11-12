#!/usr/bin/env bash
# authors.sh: for each candidate, whether its starting commit already holds the project's licence file, and who wrote
# the files it changes: every commit up to the merge commit that touched each changed path, by author, with the
# commits of bots (an author name ending in "[bot]") counted apart, and the co-author trailers of those commits.
# Also the record of the licence file itself: the commit that added it, its date, its pull request, its copyright
# line, its SHA-256, the README sentence that names it, and whether the default branch still holds the same file.
# Environment: G (a full clone of the project), NUMBERS (one pull request number per line), CLASSES (the screening's
# class rows: number in column 2, starting commit in column 4), CENSUS (the census table: number in column 1, merge
# commit in column 10), LICENCE_FILE (LICENSE), HOLDER (the copyright holder's name as the licence file gives it),
# OUT (where the three tables go), BRANCH (main).
# Writes OUT/licence_proof.tsv, OUT/authors_files.tsv (one line per candidate and changed path) and
# OUT/authors_cases.tsv (one line per candidate). Author names only; no e-mail addresses.
set -euo pipefail
: "${G:?}" "${NUMBERS:?}" "${CLASSES:?}" "${CENSUS:?}" "${HOLDER:?}" "${OUT:?}"
LICENCE_FILE=${LICENCE_FILE:-LICENSE}
BRANCH=${BRANCH:-main}
g() { git --git-dir="$G" "$@"; }
mkdir -p "$OUT"

added=$(g log --diff-filter=A --format=%H "$BRANCH" -- "$LICENCE_FILE" | tail -1)
added_date=$(g show -s --format=%cI "$added")
added_subject_pr=$(g show -s --format=%s "$added" | sed -nE 's/.*\(#([0-9]+)\)$/\1/p')
copyright=$(g show "$added:$LICENCE_FILE" | grep -m1 -i '^copyright' || true)
first_line=$(g show "$added:$LICENCE_FILE" | head -1)
sha_added=$(g show "$added:$LICENCE_FILE" | sha256sum | cut -d' ' -f1)
sha_head=$(g show "$BRANCH:$LICENCE_FILE" 2>/dev/null | sha256sum | cut -d' ' -f1)
changes=$(g log --format=%H "$BRANCH" -- "$LICENCE_FILE" | wc -l)
readme=$(g show "$added:README.md" | grep -n -m1 -i 'released under the' || true)
{
  printf 'licence_file\tfirst_line\tadded_by_commit\tadded_at\tpull_request\tcopyright_line\tsha256\tcommits_touching_it_on_%s\tsame_bytes_at_%s_head\t%s\treadme_line\treadme_sentence\n' "$BRANCH" "$BRANCH" "head_commit"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$LICENCE_FILE" "$first_line" "$added" "$added_date" "${added_subject_pr:--}" \
    "$copyright" "$sha_added" "$changes" "$([ "$sha_added" = "$sha_head" ] && echo yes || echo no)" "$(g rev-parse "$BRANCH")" \
    "${readme%%:*}" "${readme#*:}"
} > "$OUT/licence_proof.tsv"

printf 'number\tstart\tmerge\tlicence_at_start\tpath\tcommits\thuman_authors\tbot_commits\tbot_authors\tco_author_trailers\tother_than_holder\n' > "$OUT/authors_files.tsv"
printf 'number\tstart\tmerge\tlicence_at_start\tlicence_at_merge\tpaths\thuman_authors\tbot_commits\tco_author_trailers\tpaths_with_other_human_author\n' > "$OUT/authors_cases.tsv"
while read -r n; do
  start=$(awk -F'\t' -v n="$n" '$2 == n {print $4; exit}' "$CLASSES")
  merge=$(awk -F'\t' -v n="$n" '$1 == n {print $10; exit}' "$CENSUS")
  at_start=no; g merge-base --is-ancestor "$added" "$start" && at_start=yes
  at_merge=no; g merge-base --is-ancestor "$added" "$merge" && at_merge=yes
  others=0; npaths=0
  all_humans=""; all_bots=0; all_trailers=""
  while IFS= read -r path; do
    npaths=$((npaths + 1))
    log=$(g log --format='%H%x09%an%x09%(trailers:key=Co-authored-by,valueonly,separator=;)' "$merge" -- "$path")
    commits=$(printf '%s\n' "$log" | grep -c . || true)
    humans=$(printf '%s\n' "$log" | awk -F'\t' 'NF && $2 !~ /\[bot\]$/ {print $2}' | sort -u | paste -sd';' -)
    bots=$(printf '%s\n' "$log" | awk -F'\t' 'NF && $2 ~ /\[bot\]$/' | wc -l)
    botnames=$(printf '%s\n' "$log" | awk -F'\t' 'NF && $2 ~ /\[bot\]$/ {print $2}' | sort -u | paste -sd';' -)
    trailers=$(printf '%s\n' "$log" | cut -f3 | tr ';' '\n' | sed -E 's/ *<[^>]*>//; s/^ +//; s/ +$//' | grep . | sort -u | paste -sd';' - || true)
    other=$(printf '%s\n' "$humans" | tr ';' '\n' | grep . | grep -v -x -F "$HOLDER" | paste -sd';' - || true)
    [ -z "$other" ] || others=$((others + 1))
    all_humans="$all_humans;$humans"; all_bots=$((all_bots + bots)); all_trailers="$all_trailers;$trailers"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$start" "$merge" "$at_start" "$path" "$commits" "${humans:--}" \
      "$bots" "${botnames:--}" "${trailers:--}" "${other:--}" >> "$OUT/authors_files.tsv"
  done < <(g diff --no-renames --name-only "$start" "$merge")
  u() { printf '%s\n' "$1" | tr ';' '\n' | grep . | sort -u | paste -sd';' - || true; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$start" "$merge" "$at_start" "$at_merge" "$npaths" "$(u "$all_humans")" \
    "$all_bots" "$(u "$all_trailers")" "$others" >> "$OUT/authors_cases.tsv"
done < "$NUMBERS"
cat "$OUT/licence_proof.tsv"
cut -f1,4-10 "$OUT/authors_cases.tsv"
