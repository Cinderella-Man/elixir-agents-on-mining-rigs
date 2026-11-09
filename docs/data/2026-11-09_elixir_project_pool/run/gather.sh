#!/usr/bin/env bash
# Metadata only: Elixir repositories on GitHub with 100 or more stars, and Hex's most downloaded packages.
# Nothing is cloned and no project code runs.
#   OUT        output folder; raw API pages go to $OUT/raw
#   HEX_PAGES  pages of 100 packages to read from Hex (default 15)
# Needs gh (logged in), curl and jq.
set -euo pipefail
: "${OUT:?output folder}"
mkdir -p "$OUT/raw"

# GitHub's search returns at most 1,000 results a query, so the star range is split.
for range in '>=500' '200..499' '100..199'; do
  page=1
  while :; do
    f="$OUT/raw/gh_$(printf '%s' "$range" | tr -c '0-9' '_')_$page.json"
    gh api -X GET search/repositories -f q="language:Elixir stars:$range" -f sort=stars -f order=desc \
      -f per_page=100 -f page="$page" > "$f"
    sleep 2.2
    [ "$(jq '.items | length' "$f")" -lt 100 ] && break
    page=$((page + 1))
  done
done

for page in $(seq 1 "${HEX_PAGES:-15}"); do
  curl -s -m 60 "https://hex.pm/api/packages?sort=total_downloads&page=$page" > "$OUT/raw/hex_$page.json"
  sleep 1
done
