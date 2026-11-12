#!/usr/bin/env bash
# one.sh: one pull request through a running controller, start to end, before the next one starts:
#   1. its task folder: the copied folder COPIED/<id> imported as it is (factoryctl import); when there is none, or the
#      import refuses it, the folder made again from the pull request (make_one.exs through the release's rpc: the
#      bundle maker, the source check, the import check), then imported. A refusal by the maker ends here.
#      A task the controller's task folder already holds (a second try) is checked again as it is.
#   2. factoryctl check --concurrency 1 <id>; waits for the job's record to leave "running".
#   3. factoryctl export of a checked task to DATA/export/<id>, then copied to DEST/<id> (replacing an earlier try's).
# Around it: the load and free bytes at the start and the end, Docker's images (id, name, bytes) and the build cache's
# bytes (Docker's API) before and after, the wall time of each step, and the highest 1-minute load the watcher (WATCH,
# watch.sh's samples) saw during the check. A check is settled when that load stayed under SETTLE_LOAD (12).
# Environment: SRC (the factory folder, for bin/factoryctl), CTL (the controller's folder; data in CTL/data), NAME (the
# controller), LIST (the list's folder in CTL/data, staged by all.sh), NUMBER, PREFIX (the task id's prefix), COPIED
# (a folder of copied task folders; may be missing), DEST, REPOSITORY, CENSUS, SCREEN, OUT (this try's folder), WATCH,
# STOP (a file whose existence stops the wait), SETTLE_LOAD (12), HOLD (default: hold.txt beside STOP; a file of task
# ids not to start: for those one.sh exits with 3 before any step and writes nothing).
# Writes OUT/: times.tsv, state_before.json, state_after.json, import*.json, make/ (the maker's
# files), check.json, job.json, result.json, progress.log, export.json, outcome.tsv, and row.tsv through row.sh.
set -euo pipefail
: "${SRC:?}" "${CTL:?}" "${NAME:?}" "${LIST:?}" "${NUMBER:?}" "${PREFIX:?}" "${DEST:?}" "${REPOSITORY:?}" \
  "${CENSUS:?}" "${SCREEN:?}" "${OUT:?}" "${WATCH:?}" "${STOP:?}"
SETTLE_LOAD=${SETTLE_LOAD:-12}
DATA=$CTL/data
P=$DATA/$LIST
id=$PREFIX-pr-$NUMBER
HOLD=${HOLD:-$(dirname "$STOP")/hold.txt}
if [ -f "$HOLD" ] && grep -qx "$id" "$HOLD"; then echo "$id: held ($HOLD)"; exit 3; fi
ctl() { NAME=$NAME "$SRC/bin/factoryctl" "$@"; }
rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
api() { curl -s --unix-socket /var/run/docker.sock "http://localhost$1"; }
free_b() { df --output=avail -B1 / | tail -1 | tr -d ' '; }
snap() { # the image list goes through a file: as one argument it passes Linux's 128 KiB limit on a machine with many images
  local tmp
  tmp=$(mktemp -d)
  api /images/json | jq '[.[] | {id: .Id, names: (.RepoTags // []), digests: (.RepoDigests // []), bytes: .Size}]' > "$tmp/images.json"
  api '/system/df?type=build-cache' | jq '{entries: (.BuildCache | length), bytes: ([.BuildCache[].Size] | add)}' > "$tmp/cache.json"
  jq -n --arg t "$(date -Is)" --arg load "$(cut -d' ' -f1-3 /proc/loadavg)" --arg free "$(free_b)" \
    --slurpfile images "$tmp/images.json" --slurpfile cache "$tmp/cache.json" \
    '{time: $t, load: $load, free_bytes: ($free | tonumber), images: $images[0], build_cache: $cache[0]}'
  rm -rf "$tmp"
}
mkdir -p "$OUT"
printf 'step\tstart\tend\tseconds\n' > "$OUT/times.tsv"
stamp() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(($(date -d "$3" +%s) - $(date -d "$2" +%s)))" >> "$OUT/times.tsv"; }
stopped() { [ -e "$STOP" ]; }

snap > "$OUT/state_before.json"
folder=-
verdict=-; dropped_at=-; reason=-; detail=-

import_one() { # $1: a task folder; $2: the answer's file name. True when the controller took it.
  local stage=$DATA/import/$id t0
  rm -rf "$stage"; mkdir -p "$stage"
  cp -a "$1" "$stage/$id"
  t0=$(date -Is)
  ctl import "$stage" > "$OUT/$2" || true
  stamp "${2%.json}" "$t0" "$(date -Is)"
  jq -e --arg id "$id" '.ok | any(.id == $id and (.result == "imported" or .result == "unchanged"))' "$OUT/$2" > /dev/null
}

if [ -d "$CTL/tasks/$id" ]; then
  folder=held
elif [ -d "${COPIED:-/nonexistent}/$id" ] && import_one "$COPIED/$id" import_copied.json; then
  folder=copied
else
  [ ! -e "$OUT/import_copied.json" ] || folder=copied_refused
  t0=$(date -Is)
  rm -f "$P/out/$NUMBER/make.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$LIST\", \"NUMBER\" => \"$NUMBER\", \"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$CENSUS\", \"SCREEN\" => \"$SCREEN\"}); spawn(fn -> Code.eval_file(\"/data/$LIST/make_one.exs\") end)" > /dev/null
  until [ -e "$P/out/$NUMBER/make.done" ] || stopped; do sleep 5; done
  stamp make "$t0" "$(date -Is)"
  mkdir -p "$OUT/make"; cp -a "$P/out/$NUMBER/." "$OUT/make/" 2>/dev/null || true
  result=$(awk -F'\t' 'NR == 2 {print $4}' "$OUT/make/make.tsv" 2>/dev/null || true)
  if stopped; then
    verdict=stopped; reason=$(head -1 "$STOP")
  elif [ "$result" = made ] && [ -d "$P/tasks/$id" ]; then
    if [ "$folder" = copied_refused ]; then folder=made_after_refusal; else folder=made; fi
    if ! import_one "$P/tasks/$id" import.json; then
      verdict=refused; dropped_at=import; reason=$(jq -r --arg id "$id" '(.ok // [] | map(select(.id == $id or .folder == $id)) | .[0] | if . == null then null else "\(.reason): \(.detail // "-")" end) // .error // "-"' "$OUT/import.json")
    fi
  else
    folder=not_made
    verdict=refused; dropped_at=maker
    reason=$(awk -F'\t' 'NR == 2 {print $5}' "$OUT/make/make.tsv" 2>/dev/null || echo "make_one: $(cat "$P/out/$NUMBER/make.done" 2>/dev/null)")
    detail=$(awk -F'\t' 'NR == 2 {print $16}' "$OUT/make/make.tsv" 2>/dev/null || true)
  fi
fi

check_start=-; check_end=-; job=-
if [ "$verdict" = - ] && ! stopped; then
  check_start=$(date -Is)
  ctl check --concurrency 1 "$id" > "$OUT/check.json"
  job=$(jq -er '.ok' "$OUT/check.json") || { echo "check refused: $(cat "$OUT/check.json")"; exit 1; }
  J=$DATA/factory/jobs/$job
  until { [ -e "$J/job.json" ] && [ "$(jq -r '.status' "$J/job.json")" != running ]; } || stopped; do sleep 10; done
  check_end=$(date -Is)
  stamp check "$check_start" "$check_end"
  ctl job "$job" > "$OUT/job.json" || true
  cp "$J/progress.log" "$OUT/progress.log" 2>/dev/null || true
  if [ -f "$J/results/$id.json" ]; then
    cp "$J/results/$id.json" "$OUT/result.json"
    verdict=$(jq -r '.verdict' "$OUT/result.json")
    dropped_at=$(jq -r '.dropped_at // "-"' "$OUT/result.json")
    reason=$(jq -r '(.reason // "-") | tostring' "$OUT/result.json")
    detail=$(jq -r '(.detail // "-") | tostring' "$OUT/result.json")
  elif stopped; then
    verdict=stopped; reason=$(head -1 "$STOP")
  else
    verdict=error; reason=no_result
  fi
fi

if [ "$verdict" = checked ]; then
  t0=$(date -Is)
  rm -rf "$DATA/export/$id"
  ctl export "/data/export/$id" "$id" > "$OUT/export.json"
  if jq -e '.ok' "$OUT/export.json" > /dev/null; then
    mkdir -p "$DEST"
    rm -rf "$DEST/$id.new"
    cp -a "$DATA/export/$id/$id" "$DEST/$id.new"
    rm -rf "$DEST/$id"
    mv "$DEST/$id.new" "$DEST/$id"
  fi
  stamp export "$t0" "$(date -Is)"
fi

snap > "$OUT/state_after.json"
printf 'folder\t%s\nverdict\t%s\ndropped_at\t%s\nreason\t%s\ndetail\t%s\n' "$folder" "$verdict" "$dropped_at" "$reason" \
  "$(printf '%s' "$detail" | tr '\t\n' '  ' | cut -c1-2000)" > "$OUT/outcome.tsv"
OUT=$OUT WATCH=$WATCH REPOSITORY=$REPOSITORY NUMBER=$NUMBER ID=$id SETTLE_LOAD=$SETTLE_LOAD "$(dirname "$0")/row.sh"
