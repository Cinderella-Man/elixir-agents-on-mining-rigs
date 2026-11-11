#!/usr/bin/env bash
# Step 4. The per-file patches of the pull requests that are in a named pair, through GitHub's REST API (pulls/N/files,
# 100 files per page). Nothing is cloned. The patches are raw diff text: they stay in $RAW and are never committed.
#   RAW    folder for the raw files; writes $RAW/patches/<owner>__<name>/<number>.json (filename, status,
#          previous_filename, patch, additions, deletions per file) for each number in $WORK/need_<slug>.txt
#   WORK   folder with need_<owner>__<name>.txt (one pull-request number per line; repair.sh writes it)
# Pull requests already fetched are skipped, so a run can be repeated. The REST budget is logged before and after.
set -euo pipefail
: "${RAW:?folder for the raw files}"; : "${WORK:?work folder}"
mkdir -p "$RAW/patches"
budget() { gh api rate_limit --jq '.resources | "core remaining \(.core.remaining) of \(.core.limit), graphql remaining \(.graphql.remaining) of \(.graphql.limit)"'; }
echo "$(date -u +%FT%TZ) before: $(budget)" | tee -a "$RAW/rate_limit_patches.log"
for need in "$WORK"/need_*.txt; do
  slug=$(basename "$need" .txt); slug=${slug#need_}; repo="${slug/__//}"
  dir="$RAW/patches/$slug"; mkdir -p "$dir"
  total=$(wc -l < "$need"); k=0; fetched=0
  while read -r n; do
    k=$((k + 1))
    [ -s "$dir/$n.json" ] && continue
    ok=0
    for try in 1 2 3 4; do
      if gh api --paginate --slurp "repos/$repo/pulls/$n/files?per_page=100" 2> "$dir/$n.err" \
         | jq -c '[.[][] | {filename, status, previous_filename, patch, additions, deletions}]' > "$dir/$n.json.tmp" \
         && [ -s "$dir/$n.json.tmp" ]; then ok=1; break; fi
      sleep $((try * 5))
    done
    [ "$ok" = 1 ] || { echo "FAILED: $repo #$n" >&2; cat "$dir/$n.err" >&2; exit 1; }
    mv "$dir/$n.json.tmp" "$dir/$n.json"; rm -f "$dir/$n.err"
    fetched=$((fetched + 1))
    if [ $((fetched % 100)) -eq 0 ]; then echo "$repo: $k of $total, fetched $fetched, $(budget)" | tee -a "$RAW/rate_limit_patches.log"; fi
    sleep 0.3
  done < "$need"
  echo "$repo: $total pull requests, $fetched fetched this run" | tee -a "$RAW/rate_limit_patches.log"
done
echo "$(date -u +%FT%TZ) after: $(budget)" | tee -a "$RAW/rate_limit_patches.log"
