#!/usr/bin/env bash
# release.sh: build the controller's image from SRC with Buildx from the docker:cli image, then, without starting
# a controller, ask the release `factory` once (`bin/factory eval`) which labels and share it read from
# EAB_DOCKER_LABELS and EAB_CPU_SHARES, and remove the image again.
#   release.sh            writes OUT/TAG_build.log, OUT/TAG_eval.log
# Environment: WORK (SRC defaults to WORK/src, OUT to WORK/out), IMAGE (factory:t7), CLI_IMAGE (docker:cli),
# LABEL (key=value), CPU_SHARES (256), TAG (release), KEEP (1 keeps the image).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
SRC=${SRC:-$WORK/src}
OUT=${OUT:-$WORK/out}
IMAGE=${IMAGE:-factory:t7}
CLI_IMAGE=${CLI_IMAGE:-docker:cli}
CPU_SHARES=${CPU_SHARES:-256}
TAG=${TAG:-release}
docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$SRC:/src:ro" "$CLI_IMAGE" docker buildx build --provenance=false --progress=plain -t "$IMAGE" /src \
  > "$OUT/${TAG}_build.log" 2>&1
docker image inspect "$IMAGE" --format '{{.Id}} {{.Size}}' >> "$OUT/${TAG}_build.log"
docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --network none \
  -e EAB_DOCKER_LABELS="$LABEL,etf.check=release" -e EAB_CPU_SHARES="$CPU_SHARES" "$IMAGE" \
  bin/factory eval 'IO.inspect({Application.get_env(:eab, :docker_labels), Application.get_env(:eab, :cpu_shares), Eab.DockerSettings.run_args(), Eab.Inventory.config()["id"]})' \
  > "$OUT/${TAG}_eval.log" 2>&1
[ "${KEEP:-0}" = 1 ] || docker image rm "$IMAGE" >> "$OUT/${TAG}_build.log"
