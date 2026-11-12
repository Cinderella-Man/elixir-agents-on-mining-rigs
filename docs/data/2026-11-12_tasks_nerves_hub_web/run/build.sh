#!/usr/bin/env bash
# build.sh: build one of the factory's two images on the data-mining machine with its own Docker Buildx, in the
# machine's default builder (no client container).
#   build.sh tooling      the Dockerfile's target "tooling" as TOOLING_IMAGE (the image the tests run in)
#   build.sh controller   the whole Dockerfile as IMAGE (the controller)
# Environment: SRC (the factory folder), OUT (where the log and the marker go), TOOLING_IMAGE, IMAGE, LABEL
# (key=value, put on the image).
# Writes OUT/build_<what>.log and OUT/build_<what>.done (the exit code); the log starts and ends with the time.
set -euo pipefail
: "${SRC:?}" "${OUT:?}" "${LABEL:?LABEL=<key=value>}"
what=${1:?tooling|controller}
case $what in
tooling) : "${TOOLING_IMAGE:?}"; args=(--target tooling -t "$TOOLING_IMAGE"); tag=$TOOLING_IMAGE ;;
controller) : "${IMAGE:?}"; args=(-t "$IMAGE"); tag=$IMAGE ;;
*) echo "unknown image $what"; exit 2 ;;
esac
mkdir -p "$OUT"
rm -f "$OUT/build_$what.done"
rc=0
{
  date -Is
  docker buildx build --provenance=false --progress=plain --label "$LABEL" "${args[@]}" "$SRC" || rc=$?
  docker image inspect "$tag" --format 'image {{.Id}} {{.Size}}' || true
  date -Is
} > "$OUT/build_$what.log" 2>&1
echo "$rc" > "$OUT/build_$what.done"
