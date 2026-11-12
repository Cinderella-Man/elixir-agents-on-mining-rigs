#!/usr/bin/env bash
# controller.sh: the task factory's controller on a machine with Docker but no Docker Compose, and no web page.
#   controller.sh build          build the controller's image from SRC (the factory folder) with Buildx from docker:cli
#   controller.sh up             start the controller named NAME; it answers through its release's rpc command only
#   controller.sh rpc 'code'     run one line of Elixir in the controller (bin/eab rpc)
#   controller.sh down           stop and remove the controller (its data and its image stay)
# Environment: WORK (the controller's folder; its data is WORK/NAME/data), SRC (the factory folder; for build),
# RUN (this folder, for docker_shim.sh), IMAGE (elixir-task-factory:pilot), NAME (factory), CLI_IMAGE (docker:cli),
# LABEL (pascal-quants=1), CPU_SHARES (256), PREPARE_WORKERS (2), EPMD_PORT (4455: Erlang's port mapper, loopback only).
# The controller differs from compose.yaml in: no memory collection, the docker shim in front of docker, no published
# port (nothing listens but the loopback), and Erlang's distribution bound to the loopback.
set -euo pipefail
: "${WORK:?WORK=<the folder of the controller>}"
RUN=${RUN:-$(cd "$(dirname "$0")" && pwd)}
IMAGE=${IMAGE:-elixir-task-factory:pilot}
NAME=${NAME:-factory}
CLI_IMAGE=${CLI_IMAGE:-docker:cli}
LABEL=${LABEL:-pascal-quants=1}
CPU_SHARES=${CPU_SHARES:-256}
PREPARE_WORKERS=${PREPARE_WORKERS:-2}
EPMD_PORT=${EPMD_PORT:-4455}
cmd=${1:?build|up|rpc|down}

case $cmd in
build)
  : "${SRC:?SRC=<the factory folder>}"
  docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SRC:/src:ro" "$CLI_IMAGE" docker buildx build --provenance=false --progress=plain -t "$IMAGE" /src
  docker image inspect "$IMAGE" --format '{{.Id}} {{.Size}}'
  ;;
up)
  mkdir -p "$WORK/$NAME/data" "$WORK/shim"
  install -m 755 "$RUN/docker_shim.sh" "$WORK/shim/docker"
  docker run -d --name "$NAME" --label "$LABEL" --cpu-shares "$CPU_SHARES" --init --network host \
    -e EAB_PREPARE_AHEAD=4 -e EAB_PREPARE_WORKERS="$PREPARE_WORKERS" -e EAB_MEMORY=off \
    -e PATH=/opt/shim:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -e PQ_LABEL="$LABEL" -e PQ_CPU_SHARES="$CPU_SHARES" \
    -e RELEASE_DISTRIBUTION=name -e RELEASE_NODE="$NAME@127.0.0.1" \
    -e ERL_EPMD_ADDRESS=127.0.0.1 -e ERL_EPMD_PORT="$EPMD_PORT" \
    -e 'ERL_AFLAGS=-kernel inet_dist_use_interface {127,0,0,1}' \
    -v "$WORK/$NAME/data:/data" -v "$WORK/shim:/opt/shim:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE" > /dev/null
  for _ in $(seq 60); do
    "$0" rpc 'IO.puts(:up)' 2>/dev/null | grep -qx up && { echo "$NAME: up"; exit 0; }
    sleep 2
  done
  echo "$NAME: no answer"; docker logs "$NAME" 2>&1 | tail -n 20; exit 1
  ;;
rpc)
  code=${2:?code}
  printf '%s\n' "$code" | docker exec -i "$NAME" sh -c 'IFS= read -r code; exec bin/eab rpc "$code"'
  ;;
down)
  docker logs "$NAME" > "$WORK/$NAME/controller.log" 2>&1 || true
  docker rm -f "$NAME" > /dev/null
  ;;
*) echo "unknown command $cmd"; exit 2 ;;
esac
