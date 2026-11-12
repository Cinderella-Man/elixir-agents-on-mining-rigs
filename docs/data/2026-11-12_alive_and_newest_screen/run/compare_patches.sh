#!/usr/bin/env bash
# A check of git_patches.sh against GitHub's own files lists: for pull requests whose REST answer (pulls/N/files) the
# earlier job saved, make the same file with git and compare what the repair test reads from each (the pilot's files.jq:
# code and test files with their status; lines.jq: every added and removed line with its line number).
#   RAW     the raw folder holding the REST answers ($RAW/patches/<slug>/<n>.json)
#   CLONES  the clones (blob:none)      CENSUS  the census folder      WORK  scratch folder
#   PILOT   docs/data                   SLUGS   repositories (owner__name)      PER  pull requests per repository (default 25)
# Prints one line per repository: compared, files lists equal, line lists equal; and the numbers that differ.
set -euo pipefail
: "${RAW:?}"; : "${CLONES:?}"; : "${CENSUS:?}"; : "${WORK:?}"; : "${PILOT:?}"; : "${SLUGS:?}"
here="$(cd "$(dirname "$0")" && pwd)"
SCR="$PILOT/2026-11-12_pilot_pr_screen/run"; PER="${PER:-25}"
cmp="$WORK/compare"; rm -rf "$cmp"; mkdir -p "$cmp"
for slug in $SLUGS; do
  ls "$RAW/patches/$slug"/*.json 2> /dev/null | sed -E 's#.*/([0-9]+)\.json$#\1#' | sort -n | awk -v per="$PER" -v s="$slug" 'NR % 3 == 1 && ++k <= per { print s "\t" $1 }'
done > "$cmp/need.tsv"
NEED="$cmp/need.tsv" WORK="$cmp" CENSUS="$CENSUS" CLONES="$CLONES" RAW="$cmp/raw" "$here/git_patches.sh" > /dev/null
for slug in $SLUGS; do
  n=0; fe=0; le=0; diff_list=""
  while IFS=$'\t' read -r s num; do
    [ "$s" = "$slug" ] || continue
    a="$RAW/patches/$slug/$num.json"; b="$cmp/raw/patches/$slug/$num.json"
    [ -s "$b" ] || { diff_list="$diff_list $num(no_git_file)"; n=$((n + 1)); continue; }
    n=$((n + 1))
    if [ "$(jq -r -f "$SCR/files.jq" "$a" | sort | md5sum)" = "$(jq -r -f "$SCR/files.jq" "$b" | sort | md5sum)" ]; then fe=$((fe + 1)); else diff_list="$diff_list $num(files)"; fi
    if [ "$(jq -r -f "$SCR/lines.jq" "$a" | sort | md5sum)" = "$(jq -r -f "$SCR/lines.jq" "$b" | sort | md5sum)" ]; then le=$((le + 1)); else diff_list="$diff_list $num(lines)"; fi
  done < "$cmp/need.tsv"
  printf '%s\t%s compared\t%s files lists equal\t%s line lists equal\tdiffer:%s\n' "${slug/__//}" "$n" "$fe" "$le" "${diff_list:- none}"
done
