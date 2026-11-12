#!/usr/bin/env bash
# controller.sh: one task factory controller, built from the factory folder and started without Docker Compose and
# without any wrapper in front of docker: the engine itself adds the labels and the CPU share (EAB_DOCKER_LABELS,
# EAB_CPU_SHARES).
#   controller.sh build    build the controller's image IMAGE from SRC with Buildx from CLI_IMAGE
#   controller.sh up       start the controller NAME: data DATA, task folder TASKS (writable), mirrors MIRROR (read only)
#   controller.sh down     save its log to LOG, then stop and remove it (data, tasks and image stay)
# Calls go through the factory's own wrapper: NAME=$NAME $SRC/bin/factoryctl <command> ...
# Environment: SRC (the factory folder), DATA, TASKS, MIRROR (folders on the host), IMAGE (elixir-task-factory:t10),
# NAME (factory-t10), CLI_IMAGE (docker:cli), LABEL (pascal-quants=1), CPU_SHARES (256), EPMD_PORT (4510: Erlang's
# port mapper, loopback only).
set -euo pipefail
IMAGE=${IMAGE:-elixir-task-factory:t10}
NAME=${NAME:-factory-t10}
CLI_IMAGE=${CLI_IMAGE:-docker:cli}
LABEL=${LABEL:-pascal-quants=1}
CPU_SHARES=${CPU_SHARES:-256}
EPMD_PORT=${EPMD_PORT:-4510}
cmd=${1:?build|up|down}

case $cmd in
build)
  : "${SRC:?SRC=<the factory folder>}"
  docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SRC:/src:ro" "$CLI_IMAGE" docker buildx build --provenance=false --progress=plain --label "$LABEL" \
    -t "$IMAGE" /src
  docker image inspect "$IMAGE" --format '{{.Id}} {{.Size}}'
  ;;
up)
  : "${DATA:?DATA=<a new data folder>}" "${TASKS:?TASKS=<the task folder>}" "${MIRROR:?MIRROR=<the mirror folder>}"
  mkdir -p "$DATA" "$TASKS"
  docker run -d --name "$NAME" --label "$LABEL" --cpu-shares "$CPU_SHARES" --init --network host \
    -e EAB_DOCKER_LABELS="$LABEL" -e EAB_CPU_SHARES="$CPU_SHARES" \
    -e EAB_TASKS_DIR=/tasks -e EAB_MIRRORS=/mirror/mirrors.json \
    -e EAB_PREPARE_AHEAD=4 -e EAB_PREPARE_WORKERS=2 \
    -e RELEASE_DISTRIBUTION=name -e RELEASE_NODE="${NAME//-/_}@127.0.0.1" \
    -e ERL_EPMD_ADDRESS=127.0.0.1 -e ERL_EPMD_PORT="$EPMD_PORT" \
    -e 'ERL_AFLAGS=-kernel inet_dist_use_interface {127,0,0,1}' \
    -v "$DATA:/data" -v "$TASKS:/tasks" -v "$MIRROR:/mirror:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE" > /dev/null
  for _ in $(seq 60); do
    printf '%s\n' 'IO.puts(:up)' | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"' 2>/dev/null |
      grep -qx up && { echo "$NAME: up"; exit 0; }
    sleep 2
  done
  echo "$NAME: no answer"; docker logs "$NAME" 2>&1 | tail -n 20; exit 1
  ;;
down)
  : "${LOG:?LOG=<a file for the controller log>}"
  docker logs "$NAME" > "$LOG" 2>&1 || true
  docker rm -f "$NAME" > /dev/null
  ;;
*) echo "unknown command $cmd"; exit 2 ;;
esac
