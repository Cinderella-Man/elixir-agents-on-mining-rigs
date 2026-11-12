#!/usr/bin/env bash
# pool.sh: make and gate every candidate the resolver serves, radiator first, then ex338, through one controller
# (run.sh, controller.sh and gate.exs of docs/data/2026-11-12_maker_toolchain/run/ beside this file).
# JOB_ROOT/<name>-pool/ holds numbers.txt (the `resolved` lines of the list's resolve.tsv) and links src, tables, run.
# The gate starts no pull request after P5_DEADLINE (Unix seconds) or below P5_MIN_FREE bytes free.
#   pool.sh            stage, make and gate radiator, then ex338
#   pool.sh resume     radiator's gate on DATA/radiator-pool/ids.txt as it stands (written by hand), then ex338
# Environment: JOB_ROOT, WORK, NAME, P5_CONCURRENCY (3), P5_DEADLINE, P5_MIN_FREE.
set -uo pipefail
: "${JOB_ROOT:?}" "${WORK:?}" "${NAME:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
export WORK NAME P5_CONCURRENCY=${P5_CONCURRENCY:-3} P5_DEADLINE=${P5_DEADLINE:-0} P5_MIN_FREE=${P5_MIN_FREE:-0}
radiator=(RECIPE=recipes/podlove__radiator.json CENSUS=prs_podlove__radiator.tsv
  SCREEN=screen_podlove__radiator.tsv REPOSITORY=https://github.com/podlove/radiator)
st() { date -Is; df --output=avail -B1 / | tail -n 1; }
D=$WORK/$NAME/data/radiator-pool

if [ "${1:-}" = resume ]; then
  st; rm -f "$D/out/gate.done"
  "$RUN/controller.sh" rpc "System.put_env(%{\"P5_DIR\" => \"/data/radiator-pool\", \"P5_CONCURRENCY\" => \"$P5_CONCURRENCY\", \"P5_DEADLINE\" => \"$P5_DEADLINE\", \"P5_MIN_FREE\" => \"$P5_MIN_FREE\"}); spawn(fn -> Code.eval_file(\"/data/radiator-pool/gate.exs\") end)"
  until [ -e "$D/out/gate.done" ]; do sleep 30; done
  cat "$D/out/gate.done"
else
  st; env JOB="$JOB_ROOT/radiator-pool" SUB=radiator-pool "${radiator[@]}" "$RUN/run.sh" stage
  env JOB="$JOB_ROOT/radiator-pool" SUB=radiator-pool "${radiator[@]}" "$RUN/run.sh" make
  st; env JOB="$JOB_ROOT/radiator-pool" SUB=radiator-pool "${radiator[@]}" "$RUN/run.sh" gate
fi
st; env JOB="$JOB_ROOT/ex338-pool" SUB=ex338-pool "$RUN/run.sh" stage
env JOB="$JOB_ROOT/ex338-pool" SUB=ex338-pool "$RUN/run.sh" make
st; env JOB="$JOB_ROOT/ex338-pool" SUB=ex338-pool "$RUN/run.sh" gate
st
