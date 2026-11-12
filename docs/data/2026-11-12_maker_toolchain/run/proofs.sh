#!/usr/bin/env bash
# proofs.sh: job E72's runs, in order, through one controller (run.sh and controller.sh beside this file).
#   1. resolve only, every screened candidate of ex338 and of radiator (JOB_ROOT/ex338-all, JOB_ROOT/radiator-all);
#   2. make and check the proof pull requests (JOB_ROOT/ex338, JOB_ROOT/radiator), then the gate for each.
# Each JOB_ROOT/<name>/ holds numbers.txt and links src -> the factory folder, tables -> the census and screen
# tables, run -> this folder. The controller is started before (controller.sh up) and stopped after (down).
# Environment: JOB_ROOT, WORK (the controller's folder), NAME (the controller's name), P5_CONCURRENCY (3).
set -uo pipefail
: "${JOB_ROOT:?}" "${WORK:?}" "${NAME:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
export WORK NAME P5_CONCURRENCY=${P5_CONCURRENCY:-3}
radiator=(RECIPE=recipes/podlove__radiator.json CENSUS=prs_podlove__radiator.tsv
  SCREEN=screen_podlove__radiator.tsv REPOSITORY=https://github.com/podlove/radiator)
step() { date -Is; df -B1 / | tail -n 1; "$@"; }

for name in ex338-all ex338; do env JOB="$JOB_ROOT/$name" SUB=$name "$RUN/run.sh" stage; done
for name in radiator-all radiator; do env JOB="$JOB_ROOT/$name" SUB=$name "${radiator[@]}" "$RUN/run.sh" stage; done

step env JOB="$JOB_ROOT/radiator-all" SUB=radiator-all "${radiator[@]}" "$RUN/run.sh" resolve
step env JOB="$JOB_ROOT/ex338-all" SUB=ex338-all "$RUN/run.sh" resolve
step env JOB="$JOB_ROOT/ex338" SUB=ex338 "$RUN/run.sh" make
step env JOB="$JOB_ROOT/radiator" SUB=radiator "${radiator[@]}" "$RUN/run.sh" make
step env JOB="$JOB_ROOT/ex338" SUB=ex338 "$RUN/run.sh" gate
step env JOB="$JOB_ROOT/radiator" SUB=radiator "${radiator[@]}" "$RUN/run.sh" gate
date -Is; df -B1 / | tail -n 1
