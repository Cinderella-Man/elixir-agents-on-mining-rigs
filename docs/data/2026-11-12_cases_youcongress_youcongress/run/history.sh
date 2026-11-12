#!/usr/bin/env bash
# history.sh: per candidate, the census's merge commit and its first parent beside the commit of the same pull request
# on the project's rewritten default branch (found by "(#<number>)" in its subject) and that commit's first parent,
# whether each pair holds the same tree, and how many paths the census lists against how many the merge changes.
# The project rewrote its history after these merges: the census's ids are fetched by id into CLONE first.
#   history.sh <number> ... > history.tsv
# Environment: CLONE (a bare clone of the project with the census's merge commits fetched), CENSUS (the census table:
# the merge commit in column 10, the paths in the last column), BRANCH (main). Needs git.
set -euo pipefail
: "${CLONE:?}" "${CENSUS:?}"
BRANCH=${BRANCH:-main}
g() { git --git-dir="$CLONE" "$@"; }
printf 'number\tcensus_merge\tcensus_start\tdefault_branch_merge\tdefault_branch_start\tmerge_tree_same\tstart_tree_same\tcensus_paths\tmerge_paths\n'
for n in "$@"; do
  m=$(awk -F'\t' -v n="$n" '$1 == n {print $10}' "$CENSUS")
  cp=$(awk -F'\t' -v n="$n" '$1 == n {print $NF}' "$CENSUS" | tr ';' '\n' | wc -l)
  new=$(g log "$BRANCH" --format=%H --grep="(#$n)" | head -1)
  mp=$(g diff --name-only "$m^1" "$m" | wc -l)
  same() { if [ "$(g rev-parse "$1^{tree}")" = "$(g rev-parse "$2^{tree}")" ]; then echo yes; else echo no; fi; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$m" "$(g rev-parse "$m^1")" "$new" "$(g rev-parse "$new^1")" \
    "$(same "$m" "$new")" "$(same "$m^1" "$new^1")" "$cp" "$mp"
done
