#!/usr/bin/env bash
# make.sh: run the bundle maker on the build machine, in the tooling image, as the user 1000:1000 with two CPUs and
# the network (it fetches the pull requests' commits by id from GitHub; the source check fetches them again).
#   make.sh make   --repository URL --numbers 1,2,3 [--holdout JSON]   make the tasks; one result line each
#   make.sh verify [--ids a,b]                                         the source check and the import check
# Environment: WORK (the work folder: src/ is the factory folder, tables/ holds the census and screen tables,
# run/ this folder), LABEL (key=value), RECIPE (relative to src/, default recipes/axelclark__ex338.json),
# CENSUS and SCREEN (file names in tables/), TAG (the name of this step's files), IMAGE (eab-tooling:dev),
# CPU_SHARES (256), UIDGID (1000:1000).
# Writes WORK/out/TAG.log, WORK/out/TAG.done (the exit code); the tasks go to WORK/tasks/, the result lines to
# WORK/out/results.tsv (make) or WORK/out/verify.tsv (verify), the fetched commits to WORK/cache/.
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
IMAGE=${IMAGE:-eab-tooling:dev}
CPU_SHARES=${CPU_SHARES:-256}
UIDGID=${UIDGID:-1000:1000}
RECIPE=${RECIPE:-recipes/axelclark__ex338.json}
step=${1:?make|verify}
shift
TAG=${TAG:-$step}
mkdir -p "$WORK/out" "$WORK/tasks" "$WORK/cache" "$WORK/data"
chown "$UIDGID" "$WORK/out" "$WORK/tasks" "$WORK/cache" "$WORK/data"
rm -f "$WORK/out/$TAG.done"
base=(docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --cpus=2 --user "$UIDGID"
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -e MIX_ENV=test -e P4_DATA=/work/data
  -v "$WORK/src:/app" -v "$WORK/tables:/work/tables:ro" -v "$WORK/run:/work/run:ro"
  -v "$WORK/out:/work/out" -v "$WORK/tasks:/work/tasks" -v "$WORK/cache:/work/cache" -v "$WORK/data:/work/data"
  -w /app "$IMAGE" mix run /work/run/make_tasks.exs)
case $step in
make)
  cmd=("${base[@]}" make --census "/work/tables/${CENSUS:?}" --screen "/work/tables/${SCREEN:?}" --recipe "$RECIPE"
    --out /work/tasks --results /work/out/results.tsv --cache /work/cache "$@") ;;
verify) cmd=("${base[@]}" verify --out /work/tasks --results /work/out/verify.tsv "$@") ;;
*) echo "unknown step $step"; exit 2 ;;
esac
rc=0
{
  date -Is
  printf '%q ' "${cmd[@]}"
  echo
  "${cmd[@]}" || rc=$?
  date -Is
} > "$WORK/out/$TAG.log" 2>&1
echo "$rc" > "$WORK/out/$TAG.done"
