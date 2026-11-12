#!/usr/bin/env bash
# make_list.sh: the case list for run_all.sh and a table of the cases as they stand before the run.
# For each "<project folder>=<clone under CLONES>" argument: every case folder of WORK/tasks/<project folder>, newest
# merged first (provenance.json's merged_at, then the pull request's number), less the case ids named in SKIP.
# Fails, and writes no list, when a listed case folder already holds ticket.md or statement.json, or when a case's
# starting commit is not in its clone.
# Environment: WORK (case folders in WORK/tasks), CLONES, OUT (the list and the table go there), SKIP (case ids,
# space separated; optional).
# Writes OUT/tasks.txt ("<project folder>/<case id><TAB><clone>") and OUT/cases_before.tsv.
set -euo pipefail
: "${WORK:?}" "${CLONES:?}" "${OUT:?}"
SKIP=" ${SKIP:-} "
mkdir -p "$OUT"
tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.one"' EXIT
bad=0
printf 'project\tcase\tkind\tmerged\tpull_request\tstart_commit\tfix_bytes\ttests_bytes\tticket\tstatement_json\tstart_in_clone\n' \
  > "$OUT/cases_before.tsv"
for pair in "$@"; do
  project=${pair%%=*}
  clone=${pair#*=}
  : > "$tmp.one"
  for dir in "$WORK/tasks/$project"/*/; do
    id=$(basename "$dir")
    case "$SKIP" in *" $id "*) continue ;; esac
    kind=$(jq -r .task_kind "$dir/case.json")
    rev=$(jq -r .repository.revision "$dir/case.json")
    merged=$(jq -r .merged_at "$dir/provenance.json")
    pull=$(jq -r .pull_request "$dir/provenance.json")
    ticket=no
    record=no
    inclone=yes
    [ ! -e "$dir/ticket.md" ] || ticket=yes
    [ ! -e "$dir/statement.json" ] || record=yes
    git -c safe.directory='*' -C "$CLONES/$clone" cat-file -e "$rev^{commit}" 2> /dev/null || inclone=no
    [ "$ticket$record$inclone" = nonoyes ] || bad=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$merged" "${pull##*/}" "$project" "$id" "$kind" \
      "$merged" "$pull" "$rev" "$(wc -c < "$dir/reference.patch")" "$(wc -c < "$dir/reference-tests.patch")" \
      "$ticket" "$record" "$inclone" >> "$tmp.one"
  done
  sort -t$'\t' -k1,1r -k2,2nr "$tmp.one" | while IFS=$'\t' read -r _ _ rest; do
    printf '%s\t%s\n' "$rest" "$clone"
  done >> "$tmp"
done
# tmp: project, case, kind, merged, pull request, start, fix bytes, tests bytes, ticket, record, in clone, clone
cut -f1-11 "$tmp" >> "$OUT/cases_before.tsv"
if [ "$bad" -ne 0 ]; then
  echo "a listed case already has a statement or lacks its starting commit: see $OUT/cases_before.tsv" >&2
  exit 1
fi
awk -F'\t' '{ printf "%s/%s\t%s\n", $1, $2, $12 }' "$tmp" > "$OUT/tasks.txt"
echo "$(grep -c . "$OUT/tasks.txt") cases listed"
