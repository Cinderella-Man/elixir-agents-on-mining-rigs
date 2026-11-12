#!/usr/bin/env bash
# Part 1: the merged pull requests of the last 12 months by the census (GitHub's own list, read through its API by the
# earlier jobs), for the applications that have one: every merged pull request, and those merged into the default
# branch. It shows what the history count misses (rebase merges, pull requests into other branches).
#   CENSUS_DIRS  census folders (prs_<owner>__<name>.tsv[.gz]), separated by spaces
#   HIST         alive_history.sh's output (the default branch and the window's first day)
# Writes a TSV to stdout: repo, census_merged_12m, census_merged_12m_into_default, census_last_merge.
set -euo pipefail
: "${CENSUS_DIRS:?}"; : "${HIST:?}"
printf 'repo\tcensus_merged_12m\tcensus_merged_12m_into_default\tcensus_last_merge\n'
awk -F'\t' 'NR > 1 { print $1 "\t" $2 "\t" $13 }' "$HIST" | while IFS=$'\t' read -r repo branch from; do
  slug="${repo/\//__}"; f=""
  for d in $CENSUS_DIRS; do for c in "$d/prs_$slug.tsv.gz" "$d/prs_$slug.tsv"; do [ -z "$f" ] && [ -f "$c" ] && f="$c"; done; done
  [ -n "$f" ] || continue
  gzip -dcf "$f" | awk -F'\t' -v OFS='\t' -v repo="$repo" -v b="$branch" -v from="$from" '
    NR > 1 { if ($2 > last) last = $2; if ($2 >= from) { n++; if ($5 == b) d++ } }
    END { print repo, n + 0, d + 0, substr(last, 1, 10) }'
done
