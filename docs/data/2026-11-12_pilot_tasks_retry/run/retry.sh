#!/usr/bin/env bash
# retry.sh: one list of pull requests made with the bundle maker, then imported, checked and exported through the
# factory's own entry points (bin/factoryctl: import, check, export) in a running controller (controller.sh of
# docs/data/2026-11-12_factory_t10/run/). Only the making goes through the release's rpc, with make.exs of
# docs/data/2026-11-12_maker_toolchain/run/, because factoryctl has no entry point for it.
#   retry.sh stage    copy numbers.txt, the template, the image table, the hold-out list, the census and screen tables
#                     and make.exs into DATA/SUB, and the maker's Git cache from CACHE when given
#   retry.sh make     make the task folders and run the source and import checks (make.exs); waits for its marker
#   retry.sh import   factoryctl import /data/SUB/tasks; the answer to OUT/SUB_import.json
#   retry.sh check    factoryctl check --concurrency CONCURRENCY on every id the import accepted (imported or
#                     unchanged); waits for job.json to say done; the job id to OUT/SUB_job.txt
#   retry.sh export   factoryctl export /data/export/SUB on the checked ids of that job; the answer to OUT/SUB_export.json
# Environment: FACTORY (the factory folder, for bin/factoryctl), RUN (the folder with make.exs), DATA (the controller's
# data folder on the host, mounted at /data), NAME (the controller), SUB (a folder name in DATA), OUT (where answers
# go), REPOSITORY, RECIPE (a recipe file, the template), TABLE (the image table), HOLDOUT, CENSUS and SCREEN (table
# files), NUMBERS (the numbers file), CACHE (optional: a maker's Git cache to copy), CONCURRENCY (3).
set -euo pipefail
: "${FACTORY:?}" "${DATA:?}" "${NAME:?}" "${SUB:?}" "${OUT:?}"
CONCURRENCY=${CONCURRENCY:-3}
D=$DATA/$SUB
ctl() { NAME=$NAME "$FACTORY/bin/factoryctl" "$@"; }
rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
mkdir -p "$OUT"
step=${1:?stage|make|import|check|export}

case $step in
stage)
  : "${RUN:?}" "${RECIPE:?}" "${TABLE:?}" "${HOLDOUT:?}" "${CENSUS:?}" "${SCREEN:?}" "${NUMBERS:?}"
  mkdir -p "$D/tables" "$D/out"
  cp "$NUMBERS" "$D/numbers.txt"
  cp "$RECIPE" "$D/recipe.json"
  cp "$TABLE" "$D/toolchain_images.json"
  cp "$HOLDOUT" "$D/holdout.json"
  cp "$CENSUS" "$SCREEN" "$D/tables/"
  cp "$RUN/make.exs" "$D/"
  if [ -n "${CACHE:-}" ]; then cp -a "$CACHE" "$D/cache"; fi
  ;;
make)
  : "${REPOSITORY:?}" "${CENSUS:?}" "${SCREEN:?}"
  rm -f "$D/out/make.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$SUB\", \"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$(basename "$CENSUS")\", \"SCREEN\" => \"$(basename "$SCREEN")\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/make.exs\") end)"
  until [ -e "$D/out/make.done" ]; do sleep 10; done
  cat "$D/out/make.done"
  ;;
import)
  ctl import "/data/$SUB/tasks" | tee "$OUT/${SUB}_import.json"
  ;;
check)
  mapfile -t ids < <(jq -r '.ok[] | select(.result == "imported" or .result == "unchanged") | .id' "$OUT/${SUB}_import.json")
  answer=$(ctl check --concurrency "$CONCURRENCY" "${ids[@]}")
  echo "$answer"
  job=$(printf '%s' "$answer" | jq -r '.ok')
  echo "$job" > "$OUT/${SUB}_job.txt"
  until [ "$(jq -r '.status' "$DATA/factory/jobs/$job/job.json")" != running ]; do sleep 20; done
  jq -c '{status, counts}' "$DATA/factory/jobs/$job/job.json"
  ;;
export)
  job=$(cat "$OUT/${SUB}_job.txt")
  mapfile -t ids < <(awk -F'\t' 'NR > 1 && $2 == "checked" {print $1}' "$DATA/factory/jobs/$job/results.tsv")
  if [ ${#ids[@]} -eq 0 ]; then echo '{"ok": []}' | tee "$OUT/${SUB}_export.json"; exit 0; fi
  ctl export "/data/export/$SUB" "${ids[@]}" | tee "$OUT/${SUB}_export.json"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
