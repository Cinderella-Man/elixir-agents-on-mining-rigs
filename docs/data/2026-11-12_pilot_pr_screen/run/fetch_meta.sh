#!/usr/bin/env bash
# Step 1. What the census did not read: for every merged pull request of each repository, through GitHub's GraphQL API
# in pages: title, body, head branch, author, the merge commit's message and the issues GitHub records as closed by it
# (numbers, not only the count). Nothing is cloned.
#   RAW    folder for the raw pages (they hold titles and bodies: keep them out of any commit)
#   REPOS  space-separated owner/name list (default: the three pilot applications)
#   PAGE   pull requests per request (default 30)
# Needs gh (logged in) and jq. The GraphQL and REST budgets are logged before and after, and each request logs its cost.
set -euo pipefail
: "${RAW:?folder for the raw pages}"
REPOS="${REPOS:-nerves-hub/nerves_hub_web axelclark/ex338 podlove/radiator}"
PAGE="${PAGE:-30}"
mkdir -p "$RAW/meta"

budget() { gh api rate_limit --jq '.resources | "graphql remaining \(.graphql.remaining) of \(.graphql.limit), core remaining \(.core.remaining) of \(.core.limit)"'; }
echo "$(date -u +%FT%TZ) before: $(budget)" | tee -a "$RAW/rate_limit_meta.log"

# gql <file> <args to gh api graphql>: up to 4 tries, a page can time out on GitHub's side
gql() {
  local f="$1"; shift
  for try in 1 2 3 4; do
    if gh api graphql "$@" > "$f" 2>"$f.err" && jq -e '.data and (.errors | not)' "$f" > /dev/null 2>&1; then
      rm -f "$f.err"; return 0
    fi
    sleep $((try * 5))
  done
  echo "FAILED: $f" >&2; cat "$f.err" >&2; return 1
}

PRQ='query($owner:String!,$name:String!,$after:String,$n:Int!){
  rateLimit{cost remaining}
  repository(owner:$owner,name:$name){
    pullRequests(states:MERGED,first:$n,after:$after,orderBy:{field:CREATED_AT,direction:ASC}){
      totalCount pageInfo{hasNextPage endCursor}
      nodes{
        number title body mergedAt headRefName
        author{login __typename}
        mergeCommit{oid message}
        closingIssuesReferences(first:20){totalCount nodes{number repository{nameWithOwner}}}
      }
    }
  }
}'

for repo in $REPOS; do
  owner="${repo%%/*}"; name="${repo##*/}"; dir="$RAW/meta/${owner}__${name}"
  mkdir -p "$dir"; rm -f "$dir"/pr_*.json
  after=""; k=0
  while :; do
    k=$((k + 1)); f="$dir/pr_$(printf '%04d' "$k").json"
    if [ -z "$after" ]; then
      gql "$f" -f query="$PRQ" -f owner="$owner" -f name="$name" -F n="$PAGE"
    else
      gql "$f" -f query="$PRQ" -f owner="$owner" -f name="$name" -F n="$PAGE" -f after="$after"
    fi
    echo "$repo page $k: $(jq -r '"\(.data.repository.pullRequests.nodes | length) pull requests, cost \(.data.rateLimit.cost), remaining \(.data.rateLimit.remaining)"' "$f")" | tee -a "$RAW/rate_limit_meta.log"
    [ "$(jq -r '.data.repository.pullRequests.pageInfo.hasNextPage' "$f")" = true ] || break
    after=$(jq -r '.data.repository.pullRequests.pageInfo.endCursor' "$f")
    sleep 1
  done
  echo "$repo: totalCount $(jq -r '.data.repository.pullRequests.totalCount' "$f") at the last page" | tee -a "$RAW/rate_limit_meta.log"
done
echo "$(date -u +%FT%TZ) after: $(budget)" | tee -a "$RAW/rate_limit_meta.log"
