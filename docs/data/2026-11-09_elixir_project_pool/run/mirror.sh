#!/usr/bin/env bash
# Fork every repository of a list into the logged-in GitHub account and check each fork.
# Nothing is cloned. A repository that mirrors.tsv already lists is skipped.
# A fork keeps its upstream's name, except names that say nothing alone (dotcom, backend, website, ...): those
# become <owner>-<name>.
#   DATA  this data folder (appends to mirrors.tsv)
#   LIST  a TSV with a header row
#   COL   the column of LIST that holds owner/name (default 1)
#   DATE  the date to record
set -euo pipefail
: "${DATA:?}" "${LIST:?}" "${DATE:?}"
col="${COL:-1}"
me=$(gh api user --jq '.login')
[ -f "$DATA/mirrors.tsv" ] ||
  printf 'repo\tmirror\tdefault_branch\thead_at_fork\tsame_as_upstream\tforked\tactive_workflows\n' > "$DATA/mirrors.tsv"
todo=$(mktemp)
tail -n +2 "$LIST" | cut -f"$col" | while read -r repo; do
  cut -f1 "$DATA/mirrors.tsv" | grep -qxF "$repo" || echo "$repo"
done > "$todo"

fork_name() {
  case "${1#*/}" in
    dotcom|screens|backend|website|atomic|dispatch|preview|api|server|web|app) echo "${1%/*}-${1#*/}" ;;
    *) echo "${1#*/}" ;;
  esac
}

while read -r repo; do
  name=$(fork_name "$repo")
  if [ "$name" = "${repo#*/}" ]; then gh api -X POST "repos/$repo/forks" --jq '.full_name' > /dev/null
  else gh api -X POST "repos/$repo/forks" -f name="$name" --jq '.full_name' > /dev/null; fi
  sleep 4
done < "$todo"
sleep 15
while read -r repo; do
  fork="$me/$(fork_name "$repo")"
  branch=$(gh api "repos/$fork" --jq '.default_branch')
  head_fork=$(gh api "repos/$fork/commits?per_page=1" --jq '.[0].sha')
  head_up=$(gh api "repos/$repo/commits/$branch" --jq '.sha')
  active=$(gh api "repos/$fork/actions/workflows" --jq '[.workflows[] | select(.state == "active")] | length')
  same=no; [ "$head_fork" = "$head_up" ] && same=yes
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$fork" "$branch" "$head_fork" "$same" "$DATE" "$active" >> "$DATA/mirrors.tsv"
done < "$todo"
rm -f "$todo"
