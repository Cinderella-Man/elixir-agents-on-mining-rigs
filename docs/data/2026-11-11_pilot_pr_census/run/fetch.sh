#!/usr/bin/env bash
# Metadata only, nothing is cloned: every merged pull request of each repository in $REPOS, through GitHub's GraphQL
# API in pages, with its changed files (paged past 100), labels and closing-issue count.
#   RAW    folder for the raw pages (they hold titles and bodies: keep them out of any commit)
#   REPOS  space-separated owner/name list (default: the three pilot applications)
#   PAGE   pull requests per request (default 30)
# Needs gh (logged in) and jq. The GraphQL budget is checked before and after, and each request logs its cost.
set -euo pipefail
: "${RAW:?folder for the raw pages}"
REPOS="${REPOS:-nerves-hub/nerves_hub_web axelclark/ex338 podlove/radiator}"
PAGE="${PAGE:-30}"
mkdir -p "$RAW"

budget() { gh api rate_limit --jq '.resources.graphql | "graphql remaining \(.remaining) of \(.limit), resets \(.reset | todate)"'; }
echo "$(date -u +%FT%TZ) before: $(budget)" | tee -a "$RAW/rate_limit.log"

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
        number title body mergedAt baseRefName headRefName additions deletions changedFiles
        author{login __typename}
        mergeCommit{oid}
        labels(first:30){totalCount nodes{name}}
        closingIssuesReferences(first:1){totalCount}
        files(first:100){pageInfo{hasNextPage endCursor} nodes{path}}
      }
    }
  }
}'
FILEQ='query($owner:String!,$name:String!,$num:Int!,$after:String){
  repository(owner:$owner,name:$name){ pullRequest(number:$num){
    files(first:100,after:$after){pageInfo{hasNextPage endCursor} nodes{path}} } }
}'

for repo in $REPOS; do
  owner="${repo%%/*}"; name="${repo##*/}"; dir="$RAW/${owner}__${name}"
  mkdir -p "$dir"; rm -f "$dir"/pr_*.json
  after=""; k=0
  while :; do
    k=$((k + 1)); f="$dir/pr_$(printf '%04d' "$k").json"
    if [ -z "$after" ]; then
      gql "$f" -f query="$PRQ" -f owner="$owner" -f name="$name" -F n="$PAGE"
    else
      gql "$f" -f query="$PRQ" -f owner="$owner" -f name="$name" -F n="$PAGE" -f after="$after"
    fi
    # pull requests with more than 100 changed files: page through the rest and splice it into the page
    for num in $(jq -r '.data.repository.pullRequests.nodes[] | select(.files.pageInfo.hasNextPage) | .number' "$f"); do
      cur=$(jq -r --argjson n "$num" '.data.repository.pullRequests.nodes[] | select(.number == $n) | .files.pageInfo.endCursor' "$f")
      extra='[]'
      while :; do
        gql "$dir/files_tmp.json" -f query="$FILEQ" -f owner="$owner" -f name="$name" -F num="$num" -f after="$cur"
        extra=$(jq -c --argjson e "$extra" '$e + .data.repository.pullRequest.files.nodes' "$dir/files_tmp.json")
        [ "$(jq -r '.data.repository.pullRequest.files.pageInfo.hasNextPage' "$dir/files_tmp.json")" = true ] || break
        cur=$(jq -r '.data.repository.pullRequest.files.pageInfo.endCursor' "$dir/files_tmp.json")
        sleep 1
      done
      rm -f "$dir/files_tmp.json"
      jq -c --argjson n "$num" --argjson e "$extra" \
        '(.data.repository.pullRequests.nodes[] | select(.number == $n) | .files) |= (.nodes += $e | .pageInfo.hasNextPage = false)' \
        "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    done
    echo "$repo page $k: $(jq -r '"\(.data.repository.pullRequests.nodes | length) pull requests, cost \(.data.rateLimit.cost), remaining \(.data.rateLimit.remaining)"' "$f")" | tee -a "$RAW/rate_limit.log"
    [ "$(jq -r '.data.repository.pullRequests.pageInfo.hasNextPage' "$f")" = true ] || break
    after=$(jq -r '.data.repository.pullRequests.pageInfo.endCursor' "$f")
    sleep 1
  done
  echo "$repo: totalCount $(jq -r '.data.repository.pullRequests.totalCount' "$f") at the last page" | tee -a "$RAW/rate_limit.log"
done
echo "$(date -u +%FT%TZ) after: $(budget)" | tee -a "$RAW/rate_limit.log"
