#!/usr/bin/env bash
# env_tests.sh: the project's own tests at the starting commit of pull request 3155 (the commit job P3 prepared),
# with fwup, xdelta3 and mtools in the image from the template. A hand-made probe task (make_probe.sh, with its own id
# so that it never meets the maker's task for 3155) is prepared through the controller (prepare.exs), then the whole
# suite runs ROUNDS times through the engine's own runner (tests.exs), each in a fresh workspace container and fresh
# databases with no network. A watcher records the label, CPU share and network of every engine container meanwhile.
# Environment: JOB (this job's folder: run/ and src/ the factory folder with the template), DATA (the controller's
# data folder on the host), GIT_DIR (a full clone of the project), NAME (the controller), COMMAND (the suite's
# command, default the template's grading.preservation), ROUNDS (2), TEST_TIMEOUT (seconds for one suite run, 900).
set -euo pipefail
: "${JOB:?}" "${DATA:?}" "${GIT_DIR:?}" "${NAME:?}"
SUB=${SUB:-env}
D=$DATA/$SUB
ID=nerves-hub-web-probe-pr-3155
MERGE=${MERGE:-ddc55538}
RECIPE=$JOB/src/recipes/nerves-hub__nerves_hub_web.json
COMMAND=${COMMAND:-$(jq -r .grading.preservation "$RECIPE")}
ROUNDS=${ROUNDS:-2}
export NAME
rpc() { "$JOB/run/controller.sh" rpc "$1"; }
st() { echo "$(date -Is) $1 free=$(df -B1 --output=avail / | tail -n 1)"; }
step=${1:?probe|prepare|tests}

case $step in
probe)
  mkdir -p "$D/probe"
  cp "$JOB/run/prepare.exs" "$JOB/run/tests.exs" "$D/"
  merge=$(git --git-dir "$GIT_DIR" rev-parse "$MERGE^{commit}")
  merged_at=$(git --git-dir "$GIT_DIR" show -s --format=%cI "$merge")
  GIT_DIR=$GIT_DIR RECIPE=$RECIPE REPO=nerves-hub/nerves_hub_web PROJECT=nerves-hub-web-probe NUMBER=3155 \
    MERGE=$merge MERGED_AT=$merged_at LICENCE=Apache-2.0 TEST_TIMEOUT=${TEST_TIMEOUT:-900} OUT="$D/probe/$ID" \
    "$JOB/run/make_probe.sh"
  ;;
prepare)
  st prepare-start
  rm -f "$D/prepare.done"
  rpc "System.put_env(%{\"P3_DIR\" => \"/data/$SUB\", \"P3_ID\" => \"$ID\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/prepare.exs\") end)"
  until [ -e "$D/prepare.done" ]; do sleep 10; done
  st prepare-end; cat "$D/prepare.done"
  ;;
tests)
  st tests-start
  rm -f "$D/suite.done"
  rpc "System.put_env(%{\"P3_DIR\" => \"/data/$SUB\", \"P3_ID\" => \"$ID\", \"P3_TAG\" => \"suite\", \"P3_ROUNDS\" => \"$ROUNDS\", \"P3_COMMAND\" => \"$COMMAND\"}); System.delete_env(\"P3_STUB_FWUP\"); spawn(fn -> Code.eval_file(\"/data/$SUB/tests.exs\") end)"
  until [ -e "$D/suite.done" ]; do sleep 10; done
  st tests-end; cat "$D/suite.done"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
