#!/usr/bin/env bash
# make_task.sh: runs make_task.exs in the factory's tooling image (job T0), offline, and copies the task into the
# controller's data folder as DATA/incoming, where `factoryctl import /data/incoming` reads it.
# Environment: SRC (the factory folder), WORK (the job's folder), DATA (the controller's data folder),
# TASK_IMAGE (the task's pinned hexpm/elixir image), TOOLING (eab-tooling:dev), LABEL, CPU_SHARES.
set -euo pipefail
: "${SRC:?}" "${WORK:?}" "${DATA:?}" "${TASK_IMAGE:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
TOOLING=${TOOLING:-eab-tooling:dev}
docker run --rm --network none --label "${LABEL:-pascal-quants=1}" --cpu-shares "${CPU_SHARES:-256}" \
  -v "$SRC:/src:ro" -v "$RUN:/run-scripts:ro" -v "$WORK:/out" "$TOOLING" \
  elixir /run-scripts/make_task.exs /src /out "$TASK_IMAGE"
mkdir -p "$DATA/incoming"
rm -rf "$DATA/incoming/ledgerette-pr-1"
cp -a "$WORK/incoming/ledgerette-pr-1" "$DATA/incoming/"
