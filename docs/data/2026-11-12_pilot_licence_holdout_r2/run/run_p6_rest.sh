#!/usr/bin/env bash
# The licence scan and the hold-out check on the 34 checked tasks of the second batch (radiator 27, ex338 7).
#   WORK    scratch and output folder on the build machine
#   TASKS   the folder that holds the 34 task folders (radiator-pr-*, ex338-pr-*), copies; the originals stay
#   CLONES  git directories (copies of partial clones, blobs fetched by fetch_blobs.sh) that hold every starting
#           and merge commit, separated by spaces
#   BENCH   a temporary copy of the bench's cases/ folder, without admission.json (read in place; never copied
#           into a repository)
#   SRC     a checkout of this repository
#   LABEL   the label every container carries
set -euo pipefail
: "${WORK:?}" "${TASKS:?}" "${CLONES:?}" "${BENCH:?}" "${SRC:?}" "${LABEL:?}"
export WORK CLONES BENCH_CASES=$BENCH HEX_FETCH=1
export DOCKER_RUN_ARGS="--label $LABEL --cpu-shares 256" LOCAL_SPANS=$WORK/LOCAL_spans.json
date -Is
"$SRC/factory/tools/check_tasks.sh" "$TASKS"/radiator-pr-* "$TASKS"/ex338-pr-*
date -Is
