#!/usr/bin/env bash
# Part 1, step 2. From each clone's history (no request to GitHub): the default branch, its head and the head's commit
# date, the commits of the last 12 and 6 months, and the merged pull requests of the last 12 months the history shows.
#   CLONES  the clones (alive_clone.sh)
#   NOW     the reference time, seconds since 1970 (default: now); the windows start 12 and 6 calendar months before
#           its UTC date
# Writes a TSV to stdout, one row per clone.
# Commits: every commit reachable from the head of the default branch whose committer date is in the window (the
#   commits of merged branches included).
# Merged pull requests: on the first-parent line of the default branch, the distinct numbers n of commits whose subject
#   is `Merge pull request #n ...` (GitHub's merge commit), ends in `(#n)` (a squash merge or a merge queue), or starts
#   with `Merge #n` (a merge bot), counted by the committer date of that commit. A rebase merge leaves no number and is
#   not counted; a pull request merged into another branch counts only when that branch is merged with a numbered
#   subject.
# Web-flow commits: first-parent commits of the last 12 months whose committer is GitHub itself (noreply@github.com)
#   and whose subject carries no number: what a rebase merge made on github.com leaves (one per rebased commit), so a
#   sign of pull requests that the count above cannot see.
set -euo pipefail
: "${CLONES:?}"
NOW="${NOW:-$(date -u +%s)}"
day=$(date -u -d "@$NOW" +%F)
t12=$(date -u -d "$day -12 months" +%s); t6=$(date -u -d "$day -6 months" +%s)
printf 'repo\tdefault_branch\thead\thead_date\tcommits_total\tcommits_12m\tcommits_6m\tmerged_prs_12m\tby_merge_commit\tby_squash_subject\tby_bot_subject\tlast_numbered_merge\twindow_12m_from\twindow_6m_from\tweb_flow_unnumbered_12m\n'
for d in "$CLONES"/*.git; do
  [ -d "$d" ] || continue
  slug=$(basename "$d" .git); repo="${slug/__//}"
  branch=$(git -C "$d" symbolic-ref --short HEAD)
  read -r head hdate < <(git -C "$d" log -1 --format='%H %cI' HEAD)
  counts=$(git -C "$d" log --format=%ct HEAD | awk -v a="$t12" -v b="$t6" '{ n++; if ($1 >= a) x++; if ($1 >= b) y++ } END { print n + 0 "\t" x + 0 "\t" y + 0 }')
  prs=$(git -C "$d" log --first-parent --format='%ct%x09%ce%x09%s' HEAD | awk -F'\t' -v a="$t12" '
    { ct = $1; s = $3; n = ""; how = ""
      if (match(s, /^Merge pull request #[0-9]+/)) { n = substr(s, 21, RLENGTH - 20); how = "m" }
      else if (match(s, /\(#[0-9]+\)[ ]*$/)) { t = substr(s, RSTART + 2); sub(/\)[ ]*$/, "", t); n = t; how = "s" }
      else if (match(s, /^Merge #[0-9]+/)) { n = substr(s, 8, RLENGTH - 7); how = "b" }
      if (n == "") { if (ct >= a && $2 == "noreply@github.com") wf++; next }
      if (ct > last) last = ct
      if (ct >= a && !(n in seen)) { seen[n] = 1; c++; k[how]++ } }
    END { print c + 0 "\t" k["m"] + 0 "\t" k["s"] + 0 "\t" k["b"] + 0 "\t" (last ? last : "-") "\t" wf + 0 }')
  last=$(printf '%s' "$prs" | cut -f5)
  [ "$last" != "-" ] && last=$(date -u -d "@$last" +%FT%TZ)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repo" "$branch" "$head" "$hdate" "$counts" "$(printf '%s' "$prs" | cut -f1-4)" "$last" \
    "$(date -u -d "@$t12" +%F)" "$(date -u -d "@$t6" +%F)" "$(printf '%s' "$prs" | cut -f6)"
done
