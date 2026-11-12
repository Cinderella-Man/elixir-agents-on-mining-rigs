#!/usr/bin/env bash
# code_tests.sh: the factory's own checks for a change to its code, in order, on the data-mining machine: the tooling
# image built from SRC (build.sh tooling), then test.sh's steps deps, format, compile, unit and docker (the earlier
# jobs' scripts, unchanged). Stops at the first step that fails. Meant to run detached.
# Environment: SRC (the factory folder with the change), OUT, IMAGE (the tooling image's tag), LABEL (key=value),
# HEX_CACHE_ID (the BuildKit cache id for the recipe the Docker tests build).
# Writes OUT/build_tooling.log and .done, OUT/<step>.log and .done, OUT/tests/<step>.tsv (one line per test), and last
# OUT/all.done (the last exit code and the time).
set -uo pipefail
: "${SRC:?}" "${OUT:?}" "${IMAGE:?}" "${LABEL:?LABEL=<key=value>}" "${HEX_CACHE_ID:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
rm -f "$OUT/all.done"
SRC=$SRC OUT=$OUT TOOLING_IMAGE=$IMAGE LABEL=$LABEL "$RUN/build.sh" tooling
rc=$(cat "$OUT/build_tooling.done")
if [ "$rc" = 0 ]; then
  for step in deps format compile unit docker; do
    SRC=$SRC OUT=$OUT IMAGE=$IMAGE LABEL=$LABEL HEX_CACHE_ID=$HEX_CACHE_ID TAG=$step "$RUN/test.sh" "$step"
    rc=$(cat "$OUT/$step.done")
    [ "$rc" = 0 ] || break
  done
fi
echo "$rc $(date -Is)" > "$OUT/all.done"
