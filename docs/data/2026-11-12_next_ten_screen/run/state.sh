#!/usr/bin/env bash
# Step 0a. One GraphQL query per 20 applications of the approved batch: archived or not, the last push, the merged
# pull-request count now, and the language shares. Metadata only, nothing is cloned.
#   LIST  the pool's approved_app_first_batch.tsv
#   OUT   writes $OUT/state.tsv: repo, archived, pushed_at, merged_prs_now, elixir_share_now, languages
set -euo pipefail
: "${LIST:?approved_app_first_batch.tsv}"; : "${OUT:?output folder}"
mkdir -p "$OUT"
repos=$(awk -F'\t' 'NR > 1 && $3 == "application" { print $1 }' "$LIST")
printf 'repo\tarchived\tpushed_at\tmerged_prs_now\telixir_share_now\tlanguages\n' > "$OUT/state.tsv"
echo "$repos" | xargs -n 20 | while read -r chunk; do
  q='query{ rateLimit{cost remaining}'; i=0
  for r in $chunk; do
    i=$((i + 1)); q="$q r$i: repository(owner:\"${r%%/*}\",name:\"${r##*/}\"){nameWithOwner isArchived pushedAt pullRequests(states:MERGED){totalCount} languages(first:10,orderBy:{field:SIZE,direction:DESC}){totalSize edges{size node{name}}}}"
  done
  q="$q }"
  gh api graphql -f query="$q" | jq -r '.data | to_entries[] | select(.key != "rateLimit") | .value | [
      .nameWithOwner, .isArchived, .pushedAt, .pullRequests.totalCount,
      (if .languages.totalSize == 0 then 0 else ((([.languages.edges[] | select(.node.name == "Elixir") | .size] | add // 0) * 1000 / .languages.totalSize | round) / 10) end),
      ([.languages.edges[] | "\(.node.name) \(.size)"] | join(";"))] | @tsv' >> "$OUT/state.tsv"
done
wc -l < "$OUT/state.tsv"
