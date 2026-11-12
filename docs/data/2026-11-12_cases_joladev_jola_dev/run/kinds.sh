#!/usr/bin/env bash
# kinds.sh: the candidates in the screening's order (newest merged first), each with its kind read ahead from the
# project's clone by the bundle maker's rule (Eab.BundleMaker.task_kind/1: a feature when the change outside test/
# adds a file or a public function it does not also remove, else a bug fix). The order of the run is taken from it
# when one kind runs short; the kind recorded for a case is always its made folder's own (case.json task_kind).
#   kinds.sh > kinds.tsv
# Environment: CLASSES (the screening's class table of the project: repository, number, merged, starting commit, ...,
# the toolchain need in column 9), CENSUS (the census table: the merge commit in column 10), CLONE (a bare clone).
# Prints: number, merged, start, merge, needs (column 9 of CLASSES: "-" or "toolchain:rust"), kind, files_added,
# public_functions_added.
set -euo pipefail
export LC_ALL=C
: "${CLASSES:?}" "${CENSUS:?}" "${CLONE:?}"
printf 'number\tmerged\tstart\tmerge\tneeds\tkind\tfiles_added\tpublic_functions_added\n'
while IFS=$'\t' read -r _repo number merged start _e _o _c _p needs _rest; do
  merge=$(awk -F'\t' -v n="$number" '$1 == n {print $10}' "$CENSUS")
  if [ -z "$merge" ] || ! git --git-dir="$CLONE" cat-file -e "$merge^{commit}" 2>/dev/null; then
    printf '%s\t%s\t%s\t%s\t%s\t-\t-\t-\n' "$number" "$merged" "$start" "${merge:--}" "$needs"
    continue
  fi
  added=$(git --git-dir="$CLONE" diff --no-renames --name-status "$start" "$merge" -- . ':(exclude)test' \
    | awk '$1 == "A"' | wc -l)
  diff=$(git --git-dir="$CLONE" diff --no-renames "$start" "$merge" -- . ':(exclude)test')
  defs() { printf '%s\n' "$diff" | sed -nE "s/^\\$1[[:space:]]*def[[:space:]]+([a-z_][A-Za-z0-9_?!]*).*/\\1/p" | sort; }
  new=$(comm -23 <(defs +) <(defs -) | grep -c . || true)
  if [ "$added" -gt 0 ] || [ "$new" -gt 0 ]; then kind=feature; else kind=bug_fix; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$merged" "$start" "$merge" "$needs" "$kind" "$added" "$new"
done < "$CLASSES"
