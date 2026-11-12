#!/usr/bin/env bash
# Pilot job P6: the licence scan and the hold-out check on the 16 checked ex338 tasks of P5's second run.
#   WORK   scratch and output folder on the build machine
#   TASKS  the folder that holds the 16 task folders (ex338-pr-*)
#   CLONE  a git directory of axelclark/ex338 that holds every starting and merge commit
#   BENCH  the bench's cases/ folder (read in place; never copied into a repository)
#   SRC    a checkout of this repository
#   LABEL  the label every container carries
set -euo pipefail
: "${WORK:?}" "${TASKS:?}" "${CLONE:?}" "${BENCH:?}" "${SRC:?}" "${LABEL:?}"
export WORK CLONES=$CLONE BENCH_CASES=$BENCH HEX_FETCH=1
export DOCKER_RUN_ARGS="--label $LABEL --cpu-shares 256" LOCAL_SPANS=$WORK/LOCAL_spans.json
date -Is
"$SRC/factory/tools/check_tasks.sh" "$TASKS"/ex338-pr-*
date -Is
