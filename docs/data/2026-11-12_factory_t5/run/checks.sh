#!/usr/bin/env bash
# checks.sh: the format check, the tests, and the tests with Docker, one after another, with job T0's test.sh
# (docs/data/2026-11-12_factory_t0/run/), on the build machine. The browser test is left out: it builds from the
# Playwright image, which is not downloaded.
#   checks.sh TAG       writes OUT/TAG_format.*, OUT/TAG_unit.*, OUT/TAG_docker.* and OUT/tests/TAG_*.tsv
# Environment: WORK (the work folder of job T0's scripts, with run/ and src/), LABEL (key=value).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
T=${1:?TAG}
cd "$WORK"
TAG=${T}_format run/test.sh format
TAG=${T}_unit run/test.sh unit
TAG=${T}_docker run/test.sh docker --exclude module:Elixir.Eab.BrowserDockerTest
