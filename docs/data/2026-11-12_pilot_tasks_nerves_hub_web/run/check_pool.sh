#!/usr/bin/env bash
# check_pool.sh: checks a list of imported tasks through the factory's entry point (`factoryctl check`), one task per
# check job and SLOTS jobs at once, in the list's order. Before each start it reads the free space on /; below
# MIN_FREE no further task starts and the rest are written not_tried. A slot is free again when its job's job.json
# carries finished_at.
# Writes POOL/jobs.tsv (task, job, start, free bytes then), POOL/verdicts.tsv (task, verdict, step, reason),
# POOL/pool.log and the marker POOL/pool.done.
# Environment: JOB (for src/bin/factoryctl), DATA (the controller's data folder on the host), NAME (the controller),
# IDS (a file, one task id per line), POOL (a folder for the records), SLOTS (2), MIN_FREE (bytes, 0).
set -uo pipefail
: "${JOB:?}" "${DATA:?}" "${NAME:?}" "${IDS:?}" "${POOL:?}"
SLOTS=${SLOTS:-2}
MIN_FREE=${MIN_FREE:-0}
export NAME
mkdir -p "$POOL"
log() { echo "$(date -Is) $*" | tee -a "$POOL/pool.log"; }
free() { df -B1 --output=avail / | tail -n 1 | tr -d ' '; }
finished() { jq -e 'has("finished_at")' "$DATA/factory/jobs/$1/job.json" > /dev/null 2>&1; }
printf 'id\tjob\tstarted\tfree_at_start\n' > "$POOL/jobs.tsv"
printf 'id\tverdict\tdropped_at\treason\n' > "$POOL/verdicts.tsv"
declare -A running=() # job id -> task id

reap() {
  local job id v
  for job in "${!running[@]}"; do
    if finished "$job"; then
      id=${running[$job]}
      v=$(jq -r '[.verdict, (.dropped_at // "-"), (.reason // "-")] | @tsv' \
        "$DATA/factory/jobs/$job/results/$id.json" 2> /dev/null || printf 'error\t-\tno_result')
      printf '%s\t%s\n' "$id" "$v" >> "$POOL/verdicts.tsv"
      log "end $id $job $(echo "$v" | tr '\t' ' ') free=$(free)"
      unset "running[$job]"
    fi
  done
}

mapfile -t ids < <(grep . "$IDS")
log "pool: ${#ids[@]} tasks, $SLOTS at once, floor $MIN_FREE"
stop=0
for id in "${ids[@]}"; do
  while [ "${#running[@]}" -ge "$SLOTS" ]; do
    sleep 20
    reap
  done
  f=$(free)
  if [ "$stop" = 1 ] || [ "$f" -lt "$MIN_FREE" ]; then
    stop=1
    printf '%s\tnot_tried\t-\tdisk_floor\n' "$id" >> "$POOL/verdicts.tsv"
    log "not_tried $id free=$f"
    continue
  fi
  out=$("$JOB/src/bin/factoryctl" check --concurrency 1 "$id")
  job=$(printf '%s' "$out" | jq -r '.ok // empty' 2> /dev/null)
  if [ -z "$job" ]; then
    printf '%s\terror\t-\t%s\n' "$id" "$(printf '%s' "$out" | tr '\t\n' '  ')" >> "$POOL/verdicts.tsv"
    log "refused $id $out"
    continue
  fi
  running[$job]=$id
  printf '%s\t%s\t%s\t%s\n' "$id" "$job" "$(date -Is)" "$f" >> "$POOL/jobs.tsv"
  log "start $id $job free=$f"
  sleep 2
done
while [ "${#running[@]}" -gt 0 ]; do
  sleep 20
  reap
done
log "pool done"
echo done > "$POOL/pool.done"
