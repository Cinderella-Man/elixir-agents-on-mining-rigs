#!/usr/bin/env bash
# checks.sh: the format check and the tests of the changed factory folder (WORK/src) and of the reference tree
# (WORK/base, public main before the change), with job T0's test.sh, docker_shim.sh and t0_formatter.exs
# (docs/data/2026-11-12_factory_t0/run/) and compare.sh (docs/data/2026-11-12_factory_redis/run/) in WORK/run.
#   checks.sh all TAG        format (src), unit (src, base), Docker (src, base) without docker_settings_docker_test.exs
#   checks.sh settings TAG   docker_settings_docker_test.exs alone, on src and base
# docker_settings_docker_test.exs removes every image tag `elixir-task-factory:*` made on the machine while it runs,
# so it runs only when no controller on the machine builds images. Free space on / is written before and after, and
# a done marker at the end (OUT/TAG.all).
# Environment: WORK (with run/, src/, base/), LABEL (key=value).
set -uo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
mode=${1:?all|settings}
T=${2:?TAG}
cd "$WORK"
export WORK LABEL
mkdir -p out
{ date -Is; df -B1 --output=avail /; } > "out/${T}_df.txt"
files() { (cd "$1" && find test -name '*_test.exs' ! -name docker_settings_docker_test.exs | sort); }
case $mode in
all)
  SRC=$WORK/src TAG=${T}_format run/test.sh format
  SRC=$WORK/src TAG=${T}_new_unit run/test.sh unit
  SRC=$WORK/base TAG=${T}_ref_unit run/test.sh unit
  # shellcheck disable=SC2046
  SRC=$WORK/src TAG=${T}_new_docker run/test.sh docker $(files src)
  # shellcheck disable=SC2046
  SRC=$WORK/base TAG=${T}_ref_docker run/test.sh docker $(files base)
  ;;
settings)
  SRC=$WORK/src TAG=${T}_new_settings run/test.sh docker test/eab/docker_settings_docker_test.exs
  SRC=$WORK/base TAG=${T}_ref_settings run/test.sh docker test/eab/docker_settings_docker_test.exs
  ;;
*) echo "unknown mode $mode"; exit 2 ;;
esac
{ date -Is; df -B1 --output=avail /; } >> "out/${T}_df.txt"
echo done > "out/$T.all"
