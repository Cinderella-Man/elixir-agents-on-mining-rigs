#!/usr/bin/env bash
# standin.sh: the stand-in model server (standin.mjs) in a container of its own, on the host's loopback only.
#   standin.sh up SCRIPT     start it with the conversation SCRIPT (good or wrong); requests saved in OUT/SCRIPT/
#   standin.sh down          save its log to OUT/standin-<script>.log, then stop and remove it
# Environment: OUT (where the requests go), NODE_IMAGE (the Node image Pi's own runtime pins, factory/priv/pi/runtime.json),
# STANDIN_NAME (t10-standin), PORT (18110), LABEL (pascal-quants=1), CPU_SHARES (256).
set -euo pipefail
: "${OUT:?OUT=<a folder for the requests>}" "${NODE_IMAGE:?NODE_IMAGE=<node@sha256:...>}"
RUN=$(cd "$(dirname "$0")" && pwd)
STANDIN_NAME=${STANDIN_NAME:-t10-standin}
PORT=${PORT:-18110}
case ${1:?up|down} in
up)
  script=${2:?good|wrong}
  mkdir -p "$OUT/$script" && chown 1000:1000 "$OUT/$script"
  docker run -d --name "$STANDIN_NAME" --label "${LABEL:-pascal-quants=1}" --cpu-shares "${CPU_SHARES:-256}" \
    --label "t10.script=$script" --network host --read-only --user 1000:1000 \
    -e PORT="$PORT" -e BIND=127.0.0.1 -e SCRIPT="$script" -e OUT=/out \
    -v "$RUN/standin.mjs:/opt/standin/standin.mjs:ro" -v "$OUT/$script:/out" "$NODE_IMAGE" node /opt/standin/standin.mjs > /dev/null
  for _ in $(seq 30); do
    curl -sf "http://127.0.0.1:$PORT/health" > /dev/null && { echo "stand-in $script: up on 127.0.0.1:$PORT"; exit 0; }
    sleep 1
  done
  docker logs "$STANDIN_NAME"; exit 1
  ;;
down)
  script=$(docker inspect "$STANDIN_NAME" --format '{{index .Config.Labels "t10.script"}}')
  docker logs "$STANDIN_NAME" > "$OUT/standin-$script.log" 2>&1 || true
  docker rm -f "$STANDIN_NAME" > /dev/null
  ;;
esac
