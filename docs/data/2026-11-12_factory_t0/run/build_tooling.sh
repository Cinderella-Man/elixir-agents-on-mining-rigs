#!/usr/bin/env bash
# build_tooling.sh: build the factory's tooling image (its Dockerfile, target "tooling") on a machine whose docker
# has no Buildx, through a Docker client image that carries Buildx. The build runs in the machine's own builder.
# Environment: WORK (SRC defaults to WORK/src, OUT to WORK/out), IMAGE (eab-tooling:dev, the tag the engine's Docker
# tests build from), CLI_IMAGE (docker:cli), LABEL (key=value, put on the client's container), CPU_SHARES (256).
# Writes OUT/build.log and OUT/build.done (the exit code).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
SRC=${SRC:-$WORK/src}
OUT=${OUT:-$WORK/out}
IMAGE=${IMAGE:-eab-tooling:dev}
CLI_IMAGE=${CLI_IMAGE:-docker:cli}
CPU_SHARES=${CPU_SHARES:-256}
mkdir -p "$OUT"
rm -f "$OUT/build.done"
rc=0
{
  date -Is
  docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" \
    -v /var/run/docker.sock:/var/run/docker.sock -v "$SRC:/src:ro" "$CLI_IMAGE" \
    docker buildx build --provenance=false --progress=plain --target tooling -t "$IMAGE" /src || rc=$?
  docker image inspect "$IMAGE" --format 'image {{.Id}} {{.Size}}' || true
  date -Is
} > "$OUT/build.log" 2>&1
echo "$rc" > "$OUT/build.done"
