#!/usr/bin/env bash
# checks.sh: the format check, the tests, and the tests with Docker, one after another, with job T0's test.sh,
# docker_shim.sh and t0_formatter.exs (docs/data/2026-11-12_factory_t0/run/) copied into WORK/run, on the build
# machine; then proof.sh. While the Docker tests run, Docker's events for every container created and every image
# tagged are written to OUT/TAG_events.jsonl, so that the names and labels of what the tests made can be read later.
# A done marker is written at the end.
#   checks.sh TAG       writes OUT/TAG_format.*, OUT/TAG_unit.*, OUT/TAG_docker.*, OUT/TAG_proof.*,
#                       OUT/TAG_events.jsonl, OUT/tests/TAG_*.tsv, OUT/TAG.all
# Environment: WORK (the work folder, with run/ and src/), LABEL (key=value).
set -uo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
T=${1:?TAG}
cd "$WORK"
export WORK LABEL
TAG=${T}_format run/test.sh format
TAG=${T}_unit run/test.sh unit
docker events --format '{{json .}}' --filter type=container --filter event=create --filter type=image \
  --filter event=tag > "$WORK/out/${T}_events.jsonl" &
events=$!
TAG=${T}_docker run/test.sh docker
TAG=${T}_proof run/proof.sh
kill "$events"
echo done > "$WORK/out/$T.all"
