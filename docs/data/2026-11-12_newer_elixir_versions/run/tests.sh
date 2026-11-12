#!/usr/bin/env bash
# tests.sh: the factory's checks in its tooling image, one step after another: deps, format, unit (the tests without
# Docker, the parity test among them), docker (the tests with Docker). Each step is test.sh of
# docs/data/2026-11-12_factory_data_mining_machine/run/, copied beside this script with t0_formatter.exs and
# docker_shim.sh; each writes OUT/<step>.log, OUT/<step>.done and OUT/tests/<step>.tsv (one line per test).
# Environment: SRC (the factory folder), OUT, IMAGE (the tooling image), LABEL (key=value), HEX_CACHE_ID.
# Writes OUT/tests.done when the last step has ended.
set -uo pipefail
: "${SRC:?}" "${OUT:?}" "${IMAGE:?}" "${LABEL:?}" "${HEX_CACHE_ID:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
rm -f "$OUT/tests.done"
for step in deps format unit docker; do
  SRC=$SRC OUT=$OUT IMAGE=$IMAGE LABEL=$LABEL HEX_CACHE_ID=$HEX_CACHE_ID "$RUN/test.sh" "$step"
  printf '%s %s exit %s\n' "$(date -Is)" "$step" "$(cat "$OUT/$step.done")" >> "$OUT/tests_steps.log"
done
date -Is > "$OUT/tests.done"
