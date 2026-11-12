#!/usr/bin/env bash
# tasks.sh: make and check a list of nerves_hub_web pull requests through one controller: the bundle maker with the
# toolchain resolver (make.exs of docs/data/2026-11-12_maker_toolchain/run/, unchanged), then the factory's own entry
# points through bin/factoryctl (import, check, export).
#   tasks.sh stage    copy numbers.txt, the template, the image table, the hold-out list, the tables and make.exs into
#                     the controller's data
#   tasks.sh make     make the task folders and run the source check and the import check on each (make.exs)
#   tasks.sh import   import every made folder that passed both checks into the task folder (factoryctl import)
#   tasks.sh check    check the imported tasks, two at once, newest first (check_pool.sh)
#   tasks.sh export   export the checked tasks (factoryctl export) and copy them to KEEP, with one tar file of them
# Environment: JOB (this job's folder: run/, src/ the factory folder with the template, tables/, numbers.txt), DATA
# (the controller's data folder on the host), NAME (the controller), SUB (the folder in the controller's data,
# default nhw), MIN_FREE (bytes; no pull request starts below it), SLOTS (2), KEEP (where the checked folders go),
# OUT (where the tar file goes).
set -euo pipefail
: "${JOB:?}" "${DATA:?}" "${NAME:?}"
SUB=${SUB:-nhw}
D=$DATA/$SUB
REPOSITORY=https://github.com/nerves-hub/nerves_hub_web
CENSUS=prs_nerves-hub__nerves_hub_web.tsv
SCREEN=screen_nerves-hub__nerves_hub_web.tsv
export NAME
rpc() { "$JOB/run/controller.sh" rpc "$1"; }
ctl() { "$JOB/src/bin/factoryctl" "$@"; }
step=${1:?stage|make|import|check|export}

case $step in
stage)
  mkdir -p "$D/tables" "$D/out"
  cp "$JOB/numbers.txt" "$D/numbers.txt"
  cp "$JOB/src/recipes/nerves-hub__nerves_hub_web.json" "$D/recipe.json"
  cp "$JOB/src/config/holdout.json" "$D/holdout.json"
  cp "$JOB/src/config/toolchain_images.json" "$D/toolchain_images.json"
  cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$D/tables/"
  cp "$JOB/run/make.exs" "$D/"
  ;;
make)
  rm -f "$D/out/make.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$SUB\", \"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$CENSUS\", \"SCREEN\" => \"$SCREEN\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/make.exs\") end)"
  until [ -e "$D/out/make.done" ]; do sleep 15; done
  cat "$D/out/make.done"
  ;;
import)
  # only the folders that passed the source check and the import check of make.exs
  rm -rf "$D/incoming"; mkdir -p "$D/incoming"
  awk -F'\t' 'NR>1 && $2=="passed" && $3 ~ /^accepted/ {print $1}' "$D/out/verify.tsv" > "$D/ids.txt"
  while read -r id; do cp -r "$D/tasks/$id" "$D/incoming/$id"; done < "$D/ids.txt"
  ctl import "/data/$SUB/incoming" | tee "$D/out/import.json"
  ;;
check)
  # newest first: the order of numbers.txt, kept in ids_ordered.txt
  : > "$D/ids_ordered.txt"
  while read -r n; do
    id=$(grep -x -- "[a-z0-9-]*-pr-$n" "$D/ids.txt" || true)
    [ -n "$id" ] && echo "$id" >> "$D/ids_ordered.txt"
  done < <(tr -s ' ,' '\n\n' < "$D/numbers.txt" | grep .)
  IDS=$D/ids_ordered.txt POOL=$D/pool "$JOB/run/check_pool.sh"
  ;;
export)
  : "${KEEP:?}" "${OUT:?}"
  ids=$(awk -F'\t' '$2=="checked" {print $1}' "$D/pool/verdicts.tsv" | tr '\n' ' ')
  [ -n "$ids" ] || { echo "no checked task"; exit 0; }
  rm -rf "$D/export"
  # shellcheck disable=SC2086
  ctl export "/data/$SUB/export" $ids | tee "$D/out/export.json"
  mkdir -p "$KEEP" "$OUT"
  for id in $ids; do cp -r "$D/export/$id" "$KEEP/"; done
  [ -f "$D/export/results.tsv" ] && cp "$D/export/results.tsv" "$OUT/export_results.tsv"
  tar -C "$KEEP" -czf "$OUT/checked_tasks.tar.gz" .
  ls -l "$OUT/checked_tasks.tar.gz"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
