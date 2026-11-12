#!/usr/bin/env bash
# run.sh: one list of pull requests resolved, made and gated through a running controller (controller.sh of
# docs/data/2026-11-12_factory_t10/run/, a release named `factory`), with the scripts of
# docs/data/2026-11-12_maker_toolchain/run/ (resolve.exs, make.exs, gate.exs) evaluated through the release's rpc.
# It is that folder's run.sh for a controller built after the rename of job T7 (bin/factory, not bin/eab), with an
# optional Git cache to start from and a keep step that copies and packs only this list's checked folders.
#   run.sh stage     copy numbers.txt, the template, the image table, the hold-out list, the census and screen
#                    tables and the three scripts into DATA/SUB, and the Git cache CACHE when given
#   run.sh resolve   resolve every pull request's toolchain without making a task (out/resolve.tsv)
#   run.sh make      make the task folders, then the source check and the import check (out/make.tsv, verify.tsv)
#   run.sh gate      prepare, probe, gate and second round for every folder that passed both checks
#                    (CONCURRENCY at once; none starts after DEADLINE or below MIN_FREE bytes free); IDS (a file of
#                    task ids) limits it to those, in that order
#   run.sh keep      copy this list's checked folders to KEEP (refusing an id already there) and pack them into TAR
# Environment: JOB (with src/: the factory folder, tables/, run/ and NUMBERS), DATA (the controller's data folder on
# the host, mounted at /data), NAME (the controller), SUB (the list's folder in DATA), NUMBERS (default
# JOB/numbers.txt), CACHE (optional), RECIPE (relative to src/, default recipes/axelclark__ex338.json), CENSUS, SCREEN,
# REPOSITORY, CONCURRENCY (3), DEADLINE (Unix seconds, 0 for none), MIN_FREE (bytes, 0 for none), KEEP, TAR.
set -euo pipefail
: "${JOB:?}" "${DATA:?}" "${NAME:?}" "${SUB:?}"
RECIPE=${RECIPE:-recipes/axelclark__ex338.json}
CENSUS=${CENSUS:-prs_axelclark__ex338.tsv}
SCREEN=${SCREEN:-screen_axelclark__ex338.tsv}
REPOSITORY=${REPOSITORY:-https://github.com/axelclark/ex338}
NUMBERS=${NUMBERS:-$JOB/numbers.txt}
CONCURRENCY=${CONCURRENCY:-3}
D=$DATA/$SUB
rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
env_of() { printf '"P5_DIR" => "/data/%s", "REPOSITORY" => "%s", "CENSUS" => "%s", "SCREEN" => "%s"' \
  "$SUB" "$REPOSITORY" "$CENSUS" "$SCREEN"; }
step=${1:?stage|resolve|make|gate|keep}

case $step in
stage)
  [ ! -e "$D" ] || { echo "$D exists"; exit 1; }
  mkdir -p "$D/tables" "$D/out"
  cp "$NUMBERS" "$D/numbers.txt"
  cp "$JOB/src/$RECIPE" "$D/recipe.json"
  cp "$JOB/src/config/holdout.json" "$D/holdout.json"
  cp "$JOB/src/config/toolchain_images.json" "$D/toolchain_images.json"
  cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$D/tables/"
  cp "$JOB/run/make.exs" "$JOB/run/gate.exs" "$JOB/run/resolve.exs" "$D/"
  if [ -n "${CACHE:-}" ]; then cp -a "$CACHE" "$D/cache"; fi
  ;;
resolve | make)
  rm -f "$D/out/$step.done"
  rpc "System.put_env(%{$(env_of)}); spawn(fn -> Code.eval_file(\"/data/$SUB/$step.exs\") end)"
  until [ -e "$D/out/$step.done" ]; do sleep 15; done
  cat "$D/out/$step.done"
  ;;
gate)
  # ids.txt: the folders that passed both checks, or the list in IDS (a file) when given
  if [ -n "${IDS:-}" ]; then cp "$IDS" "$D/ids.txt"; else
    awk -F'\t' 'NR>1 && $2=="passed" && $3 ~ /^accepted/ {print $1}' "$D/out/verify.tsv" > "$D/ids.txt"
  fi
  rm -f "$D/out/gate.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$SUB\", \"P5_CONCURRENCY\" => \"$CONCURRENCY\", \"P5_DEADLINE\" => \"${DEADLINE:-0}\", \"P5_MIN_FREE\" => \"${MIN_FREE:-0}\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/gate.exs\") end)"
  until [ -e "$D/out/gate.done" ]; do sleep 60; done
  cat "$D/out/gate.done"
  ;;
keep)
  : "${KEEP:?}" "${TAR:?}"
  mkdir -p "$KEEP"
  ids=$(cd "$D/checked" && ls)
  for id in $ids; do [ ! -e "$KEEP/$id" ] || { echo "$KEEP/$id exists"; exit 1; }; done
  for id in $ids; do cp -r "$D/checked/$id" "$KEEP/$id"; done
  # shellcheck disable=SC2086
  tar -C "$D/checked" -czf "$TAR" $ids
  ls -l "$TAR"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
