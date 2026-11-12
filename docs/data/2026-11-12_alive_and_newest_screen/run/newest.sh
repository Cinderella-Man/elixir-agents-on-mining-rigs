#!/usr/bin/env bash
# Part 2: the candidates to carry on, per repository, from the newest merged pull request backwards, until CAP
# candidates or the first merge before SINCE, whichever comes first.
#   PILOT   docs/data     CENSUS  the census folder     SCREEN  the folder with screen_<slug>.tsv[.gz]
#   SLUGS   the repositories (owner__name, separated by spaces)
#   SINCE   default 2024-01-01     CAP  default 150
# Writes to stdout: slug, number, merged_at, merge_commit (the input of git_tree_fetch.sh).
set -euo pipefail
: "${PILOT:?}"; : "${CENSUS:?}"; : "${SCREEN:?}"; : "${SLUGS:?}"
SINCE="${SINCE:-2024-01-01}"; CAP="${CAP:-150}"
all=$(mktemp); trap 'rm -f "$all"' EXIT
CENSUS="$CENSUS" SCREEN="$SCREEN" "$PILOT/2026-11-12_next_ten_screen/run/candidates.sh" > "$all"
for slug in $SLUGS; do
  awk -F'\t' -v s="$slug" -v since="$SINCE" '$1 == s && $3 >= since' "$all" | sort -t$'\t' -k3,3r -k2,2nr | awk -v cap="$CAP" 'NR <= cap'
done
