#!/usr/bin/env bash
# list.sh: the starting commits resolve.exs reads, as "repo\tnumber\tcommit": every candidate of the newest-first
# screen (its classes.tsv: repo, number, merged_at, start_commit, ...; at most 150 per project, docs/data/
# 2026-11-12_alive_and_newest_screen), then each clone's head as "repo\thead\tcommit". Only the projects in the first
# column of PROJECTS (the dataset's projects.tsv, docs/data/2026-11-12_dataset_projects) are kept.
# Environment: CLASSES, CLONES (clones named <owner>__<repo>.git), PROJECTS.
set -euo pipefail
: "${CLASSES:?}" "${CLONES:?}" "${PROJECTS:?}"
{
  awk -F'\t' 'NR > 1 { print $1 "\t" $2 "\t" $4 }' "$CLASSES"
  for dir in "$CLONES"/*.git; do
    name=$(basename "$dir" .git)
    printf '%s\thead\t%s\n' "${name/__//}" "$(git -C "$dir" rev-parse HEAD)"
  done
} | awk -F'\t' 'FNR == NR { if (FNR > 1) keep[$1] = 1; next } $1 in keep' "$PROJECTS" -
