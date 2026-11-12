#!/usr/bin/env bash
# run.sh: job P5 for one project, on the machine with Docker, through the controller.
#   run.sh stage     copy numbers.txt, the recipe, the hold-out list and the two tables into the controller's data
#   run.sh make      make the task folders and check them (make.exs); waits for its marker
#   run.sh gate      prepare, probe, gate and second round for every made folder (gate.exs); waits for its marker
#   run.sh keep      copy the checked folders to KEEP and write one tar file of them
# Environment: JOB (this job's folder: run/ with these scripts and controller.sh, src/ the factory folder, tables/,
# numbers.txt), WORK (the controller's folder; its data is WORK/NAME/data), NAME (factory), IMAGE (the controller's
# image), RECIPE (relative to src/, default recipes/axelclark__ex338.json), CENSUS and SCREEN (file names in
# tables/), REPOSITORY, P5_CONCURRENCY (2), KEEP (where the checked folders are copied).
# The controller is started and stopped with controller.sh (up, down) around these steps.
set -euo pipefail
: "${JOB:?}" "${WORK:?}"
NAME=${NAME:-factory}
RECIPE=${RECIPE:-recipes/axelclark__ex338.json}
CENSUS=${CENSUS:-prs_axelclark__ex338.tsv}
SCREEN=${SCREEN:-screen_axelclark__ex338.tsv}
REPOSITORY=${REPOSITORY:-https://github.com/axelclark/ex338}
P5_CONCURRENCY=${P5_CONCURRENCY:-2}
DATA=$WORK/$NAME/data/p5
export WORK NAME
rpc() { "$JOB/run/controller.sh" rpc "$1"; }
step=${1:?stage|make|gate|keep}

case $step in
stage)
  mkdir -p "$DATA/tables" "$DATA/out"
  cp "$JOB/numbers.txt" "$DATA/numbers.txt"
  cp "$JOB/src/$RECIPE" "$DATA/recipe.json"
  cp "$JOB/src/config/holdout.json" "$DATA/holdout.json"
  cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$DATA/tables/"
  cp "$JOB/run/make.exs" "$JOB/run/gate.exs" "$DATA/"
  ;;
make)
  rm -f "$DATA/out/make.done"
  rpc "System.put_env(%{\"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$CENSUS\", \"SCREEN\" => \"$SCREEN\"}); spawn(fn -> Code.eval_file(\"/data/p5/make.exs\") end)"
  until [ -e "$DATA/out/make.done" ]; do sleep 15; done
  cat "$DATA/out/make.done"
  ;;
gate)
  # ids.txt: the made folders that passed the source check and the import check
  awk -F'\t' 'NR>1 && $2=="passed" && $3 ~ /^accepted/ {print $1}' "$DATA/out/verify.tsv" > "$DATA/ids.txt"
  rm -f "$DATA/out/gate.done"
  rpc "System.put_env(\"P5_CONCURRENCY\", \"$P5_CONCURRENCY\"); spawn(fn -> Code.eval_file(\"/data/p5/gate.exs\") end)"
  until [ -e "$DATA/out/gate.done" ]; do sleep 60; done
  cat "$DATA/out/gate.done"
  ;;
keep)
  : "${KEEP:?}"
  mkdir -p "$KEEP"
  cp -r "$DATA/checked/." "$KEEP/"
  tar -C "$KEEP" -czf "$JOB/out/checked_tasks.tar.gz" .
  ls -l "$JOB/out/checked_tasks.tar.gz"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
