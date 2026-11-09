#!/usr/bin/env bash
# Per repository, in batches through GitHub's GraphQL API (metadata only, nothing is cloned):
# merged pull requests, whether the default branch has a test/ folder and a mix.exs at its root,
# and, where GitHub named no licence, the first 400 characters of the licence file.
#   OUT  the folder build.sh wrote to; reads projects_all.tsv, writes prs.tsv and licence_heads.tsv
set -euo pipefail
: "${OUT:?output folder}"
mkdir -p "$OUT/raw"
tail -n +2 "$OUT/projects_all.tsv" | awk -F'\t' '$6 == "-" && $5 != "copyleft" && $5 != "weak_copyleft" {print $1 "\t" $5}' > "$OUT/repos.txt"
rm -f "$OUT"/raw/gql_*.json "$OUT"/chunk_*
split -l 15 -a 3 -d "$OUT/repos.txt" "$OUT/chunk_"
for c in "$OUT"/chunk_*; do
  q=$(awk -F'\t' '{ split($1, p, "/");
    lic = ($2 == "none" || $2 == "check") ? " l1: object(expression: \"HEAD:LICENSE\") { ... on Blob { text } } l2: object(expression: \"HEAD:LICENSE.md\") { ... on Blob { text } } l3: object(expression: \"HEAD:LICENSE.txt\") { ... on Blob { text } } l4: object(expression: \"HEAD:COPYING\") { ... on Blob { text } }" : "";
    printf "r%d: repository(owner: \"%s\", name: \"%s\") { nameWithOwner pullRequests(states: MERGED) { totalCount } tests: object(expression: \"HEAD:test\") { __typename } mix: object(expression: \"HEAD:mix.exs\") { __typename }%s }\n", NR, p[1], p[2], lic }' "$c")
  f="$OUT/raw/gql_$(basename "$c").json"
  for try in 1 2 3 4; do   # a large batch can time out on GitHub's side: retry
    gh api graphql -f query="query { $q }" > "$f" 2>/dev/null || true
    jq -e ".data" "$f" > /dev/null 2>&1 && break
    echo "{}" > "$f"; sleep 5
  done
  sleep 1
done
{
  printf 'repo\tmerged_prs\ttest_dir\tmix_exs\n'
  jq -r '.data // {} | to_entries[] | select(.value != null) | .value
         | [.nameWithOwner, .pullRequests.totalCount, (if .tests then "yes" else "no" end), (if .mix then "yes" else "no" end)] | @tsv' "$OUT"/raw/gql_chunk_*.json
} > "$OUT/prs.tsv"
{
  printf 'repo\tlicence_head\n'
  jq -r '.data // {} | to_entries[] | select(.value != null) | .value
         | select(has("l1"))
         | [.nameWithOwner, ((.l1.text // .l2.text // .l3.text // .l4.text // "") | gsub("[\\t\\n\\r ]+"; " ") | .[0:400])] | @tsv' "$OUT"/raw/gql_chunk_*.json
} > "$OUT/licence_heads.tsv"
