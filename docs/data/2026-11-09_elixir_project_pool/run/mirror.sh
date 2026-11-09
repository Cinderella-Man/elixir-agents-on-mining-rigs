#!/usr/bin/env bash
# Fork every approved repository into the logged-in GitHub account and check each fork.
# Nothing is cloned. A fork that already exists is returned as it is.
#   DATA  this data folder (reads approved_first_batch.tsv, writes mirrors.tsv)
#   DATE  the date to record
set -euo pipefail
: "${DATA:?}" "${DATE:?}"
me=$(gh api user --jq '.login')
printf 'repo\tmirror\tdefault_branch\thead_at_fork\tsame_as_upstream\tforked\tactive_workflows\n' > "$DATA/mirrors.tsv"
tail -n +2 "$DATA/approved_first_batch.tsv" | cut -f1 | while read -r repo; do
  gh api -X POST "repos/$repo/forks" --jq '.full_name' > /dev/null
  sleep 4
done
sleep 20
tail -n +2 "$DATA/approved_first_batch.tsv" | cut -f1 | while read -r repo; do
  fork="$me/${repo#*/}"
  branch=$(gh api "repos/$fork" --jq '.default_branch')
  head_fork=$(gh api "repos/$fork/commits?per_page=1" --jq '.[0].sha')
  head_up=$(gh api "repos/$repo/commits/$branch" --jq '.sha')
  active=$(gh api "repos/$fork/actions/workflows" --jq '[.workflows[] | select(.state == "active")] | length')
  same=no; [ "$head_fork" = "$head_up" ] && same=yes
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$fork" "$branch" "$head_fork" "$same" "$DATE" "$active" >> "$DATA/mirrors.tsv"
done
