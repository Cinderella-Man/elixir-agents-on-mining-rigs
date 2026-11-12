#!/usr/bin/env bash
# resolve.sh: resolve.exs in the factory's tooling image, on the factory folder's compiled test build (run after
# tests.sh), with the clones mounted read only and no network. Prints resolve.exs's TSV.
# Environment: SRC (the factory folder), CLONES, LIST (a file), TABLE (a file), IMAGE (the tooling image),
# LABEL (key=value), CPU_SHARES (256). Only the 9-column lines are kept (the VM prints a warning about libsctp first).
set -euo pipefail
: "${SRC:?}" "${CLONES:?}" "${LIST:?}" "${TABLE:?}" "${IMAGE:?}" "${LABEL:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
docker run --rm --label "$LABEL" --cpu-shares "${CPU_SHARES:-256}" --cpus=2 --user 1000:1000 --network none \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -e MIX_ENV=test -e CLONES=/clones -e LIST=/in/list.tsv -e TABLE=/in/table.json \
  -v "$SRC:/app" -w /app -v "$CLONES:/clones:ro" -v "$(realpath "$LIST"):/in/list.tsv:ro" \
  -v "$(realpath "$TABLE"):/in/table.json:ro" -v "$RUN/resolve.exs:/opt/run/resolve.exs:ro" \
  "$IMAGE" mix run --no-start --no-compile --no-deps-check /opt/run/resolve.exs | awk -F"\t" "NF == 9"
