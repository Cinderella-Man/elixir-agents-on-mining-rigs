#!/usr/bin/env bash
# env_tests.sh: hexpm's own tests at the starting commit of one pull request (NUMBER, its merge commit MERGE), with
# the template's package (postgresql-client) and, when IMAGE is set, the Elixir image the resolver gives that commit
# in place of the template's default (env_tests.sh of docs/data/2026-11-12_tasks_nerves_hub_web, for hexpm).
# A hand-made probe task (make_probe.sh, with its own id so that it never meets the maker's task for that pull
# request) is prepared through the controller (prepare.exs), then the whole suite runs ROUNDS times through the
# engine's own runner (tests.exs), each in a fresh workspace container and fresh databases with no network.
# Environment: JOB (this job's folder: run/ and src/ the factory folder with the template), DATA (the controller's
# data folder on the host), GIT_DIR (a full clone of the project), NAME (the controller), COMMAND (the suite's
# command, default the template's grading.preservation), ROUNDS (2), TEST_TIMEOUT (seconds for one suite run, 900),
# NUMBER (2118), MERGE (its merge commit), IMAGE (optional), SUB (the folder in DATA; env), STOP (optional: a file
# whose existence ends a wait).
set -euo pipefail
: "${JOB:?}" "${DATA:?}" "${GIT_DIR:?}" "${NAME:?}"
SUB=${SUB:-env}
D=$DATA/$SUB
NUMBER=${NUMBER:-2118}
ID=hexpm-probe-pr-$NUMBER
MERGE=${MERGE:?}
RECIPE=$JOB/src/recipes/hexpm__hexpm.json
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
  GIT_DIR=$GIT_DIR RECIPE=$RECIPE REPO=hexpm/hexpm PROJECT=hexpm-probe NUMBER=$NUMBER \
    MERGE=$merge MERGED_AT=$merged_at LICENCE=Apache-2.0 TEST_TIMEOUT=${TEST_TIMEOUT:-900} IMAGE=${IMAGE:-} OUT="$D/probe/$ID" \
    "$JOB/run/make_probe.sh"
  ;;
prepare)
  st prepare-start
  rm -f "$D/prepare.done"
  rpc "System.put_env(%{\"P3_DIR\" => \"/data/$SUB\", \"P3_ID\" => \"$ID\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/prepare.exs\") end)"
  until [ -e "$D/prepare.done" ] || [ -e "${STOP:-/nonexistent}" ]; do sleep 10; done
  st prepare-end; cat "$D/prepare.done" 2>/dev/null || { echo "stopped: $(head -1 "$STOP")"; exit 1; }
  ;;
tests)
  st tests-start
  rm -f "$D/suite.done"
  rpc "System.put_env(%{\"P3_DIR\" => \"/data/$SUB\", \"P3_ID\" => \"$ID\", \"P3_TAG\" => \"suite\", \"P3_ROUNDS\" => \"$ROUNDS\", \"P3_COMMAND\" => \"$COMMAND\"}); spawn(fn -> Code.eval_file(\"/data/$SUB/tests.exs\") end)"
  until [ -e "$D/suite.done" ] || [ -e "${STOP:-/nonexistent}" ]; do sleep 10; done
  st tests-end; cat "$D/suite.done" 2>/dev/null || { echo "stopped: $(head -1 "$STOP")"; exit 1; }
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
