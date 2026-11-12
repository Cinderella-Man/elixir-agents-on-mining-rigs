#!/usr/bin/env bash
# tables.sh: this run's tables on the data-mining machine: table.sh's tasks, counts and images, and the tasks table
# with two more columns, own_images and own_images_docker_bytes: the images the try added that carry this job's label
# (JOB_LABEL), counted, and the sum of Docker's size of each (sizes overlap: images share layers). An image removed
# since is counted with the bytes the try's snapshot recorded.
# Environment: OUT (all.sh's output folder), NUMBERS, PREFIX, TASKDIR, SCREEN_TSV (for table.sh), JOB_LABEL
# (key=value), RUN (this folder's run/). Writes OUT/tables/{tasks,counts,images}.tsv and OUT/tables/tasks_own.tsv.
set -euo pipefail
: "${OUT:?}" "${NUMBERS:?}" "${TASKDIR:?}" "${SCREEN_TSV:?}" "${JOB_LABEL:?}" "${RUN:?}"
mkdir -p "$OUT/tables"
for t in tasks counts images; do
  OUT=$OUT NUMBERS=$NUMBERS PREFIX=${PREFIX:-croniq} TASKDIR=$TASKDIR SCREEN_TSV=$SCREEN_TSV \
    "$RUN/table.sh" "$t" > "$OUT/tables/$t.tsv"
done
key=${JOB_LABEL%%=*} val=${JOB_LABEL#*=}
own() { # $1 id, $2 try: the count and bytes of the try's added images that carry the job's label
  local f=$OUT/$1/$2/images_added.tsv n=0 b=0 img bytes l
  if [ -s "$f" ]; then
    while IFS=$'\t' read -r img _names bytes; do
      l=$(docker image inspect "$img" --format "{{index .Config.Labels \"$key\"}}" 2>/dev/null || true)
      if [ "$l" = "$val" ]; then n=$((n + 1)); b=$((b + bytes)); fi
    done < "$f"
  fi
  printf '%s\t%s' "$n" "$b"
}
{
  head -1 "$OUT/tables/tasks.tsv" | tr -d '\n'; printf '\town_images\town_images_docker_bytes\n'
  tail -n +2 "$OUT/tables/tasks.tsv" | while IFS= read -r line; do
    try=$(printf '%s' "$line" | cut -f1) id=$(printf '%s' "$line" | cut -f3)
    if [ "$try" = - ]; then printf '%s\t-\t-\n' "$line"; else printf '%s\t%s\n' "$line" "$(own "$id" "$try")"; fi
  done
} > "$OUT/tables/tasks_own.tsv"
wc -l "$OUT/tables/"*.tsv
