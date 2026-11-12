#!/usr/bin/env bash
# checks.sh: the format check, the tests, and the tests with Docker, one after another, with job T0's test.sh,
# docker_shim.sh and t0_formatter.exs (docs/data/2026-11-12_factory_t0/run/) copied into WORK/run, on the build
# machine. The Redis image the Docker test names must be on the machine first (REDIS, pulled by digest). Free space
# on / is written before and after, and a done marker at the end.
#   checks.sh TAG       writes OUT/TAG_format.*, OUT/TAG_unit.*, OUT/TAG_docker.*, OUT/tests/TAG_*.tsv,
#                       OUT/TAG_df.txt, OUT/TAG.all
# Environment: WORK (the work folder, with run/ and src/), LABEL (key=value),
# REDIS (default: the image redis_service_docker_test.exs names).
set -uo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
T=${1:?TAG}
REDIS=${REDIS:-redis:7.2-alpine@sha256:2f66de68111e64c3927859f158f8e666066dae2b97d9f82770a6f37a5aa1c335}
cd "$WORK"
export WORK LABEL
mkdir -p out
{ date -Is; df -B1 --output=avail /; } > "out/${T}_df.txt"
if ! docker image inspect "$REDIS" --format '{{.Id}} {{.Size}}' >> "out/${T}_df.txt"; then
  echo "missing $REDIS" >> "out/${T}_df.txt"
  echo missing > "out/$T.all"
  exit 1
fi
TAG=${T}_format run/test.sh format
TAG=${T}_unit run/test.sh unit
TAG=${T}_docker run/test.sh docker
{ date -Is; df -B1 --output=avail /; } >> "out/${T}_df.txt"
echo done > "out/$T.all"
