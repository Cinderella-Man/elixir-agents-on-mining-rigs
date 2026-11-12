#!/usr/bin/env bash
# Runs run/extra_checks.py (the three extra tables) in the tooling container, after run_p6_rest.sh.
# Same environment as run_p6_rest.sh: WORK, TASKS, BENCH, SRC, LABEL.
set -euo pipefail
: "${WORK:?}" "${TASKS:?}" "${BENCH:?}" "${SRC:?}" "${LABEL:?}"
IMAGE=${IMAGE:-python:3.12-slim-bookworm}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOOLS=$SRC/factory/tools
HOLDOUT=$SRC/factory/config/holdout.json
py() {
  docker run --rm --network none --label "$LABEL" --cpu-shares 256 -u "$(id -u):$(id -g)" -w "$WORK" \
    -v "$HERE:$HERE:ro" -v "$TOOLS:$TOOLS:ro" -v "$HOLDOUT:$HOLDOUT:ro" -v "$WORK:$WORK" -v "$TASKS:$TASKS:ro" \
    -v "$BENCH:$BENCH:ro" "$IMAGE" "$@"
}
py python -I "$HERE/extra_checks.py" deps --tools "$TOOLS" --work "$WORK" --holdout "$HOLDOUT" "$TASKS"/*
py python -I "$HERE/extra_checks.py" runs --tools "$TOOLS" --work "$WORK" --bench "$BENCH" "$TASKS"/*
