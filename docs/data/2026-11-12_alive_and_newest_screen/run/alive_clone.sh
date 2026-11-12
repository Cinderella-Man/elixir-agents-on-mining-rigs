#!/usr/bin/env bash
# Part 1, step 1. One clone per application, from github.com without a sign-in: bare, the default branch only, with
# its commits and trees but no file contents (`--filter=blob:none`); the files that are read later (at the heads, at
# starting commits, in pull requests' diffs) are fetched when they are read. A clone that exists is kept, so a run can
# be repeated. One clone at a time; the stop rules (guard.sh) are checked before each.
#   REPOS     select.sh's output (column 1: owner/name)
#   HOLDOUT   factory/config/holdout.json: an application named there (repository, organisation or name) is skipped
#   CLONES    folder for the clones, <owner>__<name>.git
# Writes $CLONES/clone_log.tsv: repo, filter, seconds, bytes on disk, default branch, status.
set -euo pipefail
: "${REPOS:?}"; : "${HOLDOUT:?}"; : "${CLONES:?}"
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/guard.sh"
mkdir -p "$CLONES"
log="$CLONES/clone_log.tsv"
[ -f "$log" ] || printf 'repo\tfilter\tseconds\tbytes\tdefault_branch\tstatus\n' > "$log"
hold=$(jq -r '([.projects[].repository] + (.organisations // []) + (.names // [])) | map(ascii_downcase) | join(" ")' "$HOLDOUT")
filter=blob:none
awk -F'\t' 'NR > 1 { print $1 }' "$REPOS" | while read -r repo; do
  slug="${repo/\//__}"; dst="$CLONES/$slug.git"
  lc=$(printf '%s' "$repo" | tr 'A-Z' 'a-z')
  skip=""
  for h in $hold; do
    if [ "$lc" = "$h" ] || [ "${lc%%/*}" = "$h" ] || [ "${lc##*/}" = "$h" ]; then skip="holdout:$h"; fi
  done
  if [ -n "$skip" ]; then printf '%s\t-\t-\t-\t-\t%s\n' "$repo" "$skip" >> "$log"; continue; fi
  [ -d "$dst" ] && continue
  guard || exit 3
  t0=$(date +%s); status=ok
  rm -rf "$dst.tmp"
  for try in 1 2 3; do
    if git clone -q --bare --single-branch --filter="$filter" "https://github.com/$repo" "$dst.tmp" 2> "$CLONES/$slug.err"; then
      status=ok; break
    fi
    status="failed:$(tr '\n' ' ' < "$CLONES/$slug.err" | cut -c1-200)"; rm -rf "$dst.tmp"; sleep $((try * 10))
  done
  if [ "$status" = ok ]; then mv "$dst.tmp" "$dst"; rm -f "$CLONES/$slug.err"; fi
  t1=$(date +%s)
  bytes=$( [ -d "$dst" ] && du -sb "$dst" | cut -f1 || echo -)
  branch=$( [ -d "$dst" ] && git -C "$dst" symbolic-ref --short HEAD || echo -)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$filter" "$((t1 - t0))" "$bytes" "$branch" "$status" >> "$log"
  echo "$repo: $status, $((t1 - t0)) s, $bytes bytes"
done
