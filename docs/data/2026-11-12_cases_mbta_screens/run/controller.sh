#!/usr/bin/env bash
# controller.sh: one task factory controller beside another controller and a bench controller on the same Docker
# (controller.sh of docs/data/2026-11-12_factory_data_mining_machine/run/, with several labels, the preparation
# limits and the hosts a release file may come from as settings). Every host path is mounted at the same path inside.
#   controller.sh up     start the controller NAME: data CTL/data, task folder CTL/tasks (both writable), SOURCES (a
#                        folder to read task folders and tables from, read only); waits until it answers rpc
#   controller.sh rpc 'ELIXIR'   evaluate one line in the running controller
#   controller.sh stop   save its log to CTL/logs/controller.log, then stop it (the container, data and image stay)
#   controller.sh start  start the stopped container again and wait until it answers
# Calls to the entry points go through the factory's own wrapper: NAME=$NAME $SRC/bin/factoryctl <command> ...
# Environment: CTL (the controller's own folder), SOURCES, IMAGE, NAME (factory), LABELS (key=value[,key=value...]:
# on the container and on everything the engine starts or builds), CPU_SHARES (256), EPMD_PORT (4510: Erlang's port
# mapper, loopback only), HEX_CACHE_ID (the BuildKit cache id of the workspace recipe's Hex packages),
# PREPARE_WORKERS (1) and PREPARE_AHEAD (1), the engine's preparation limits for runs; RELEASE_FILE_HOSTS (the hosts a
# task's release files may come from, space separated; empty by default, as in the engine).
# The image declares VOLUME /data; CTL/data is also mounted there, so Docker makes no anonymous volume.
set -euo pipefail
: "${CTL:?CTL=<the controller folder>}"
NAME=${NAME:-factory}
CPU_SHARES=${CPU_SHARES:-256}
EPMD_PORT=${EPMD_PORT:-4510}
cmd=${1:?up|rpc|stop|start}

rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
wait_up() {
  for _ in $(seq 90); do
    rpc 'IO.puts(:up)' 2>/dev/null | grep -qx up && { echo "$NAME: up $(date -Is)"; return 0; }
    sleep 2
  done
  echo "$NAME: no answer"; docker logs "$NAME" 2>&1 | tail -n 20; return 1
}

case $cmd in
up)
  : "${SOURCES:?}" "${IMAGE:?}" "${HEX_CACHE_ID:?}" "${LABELS:?LABELS=<key=value[,key=value...]>}"
  label_args=()
  IFS=, read -ra labels <<< "$LABELS"
  for l in "${labels[@]}"; do label_args+=(--label "$l"); done
  mkdir -p "$CTL/data" "$CTL/tasks" "$CTL/logs"
  docker run -d --name "$NAME" "${label_args[@]}" --cpu-shares "$CPU_SHARES" --init --network host \
    -e EAB_DATA_DIR="$CTL/data" -e EAB_TASKS_DIR="$CTL/tasks" \
    -e EAB_DOCKER_LABELS="$LABELS" -e EAB_CPU_SHARES="$CPU_SHARES" -e EAB_HEX_CACHE_ID="$HEX_CACHE_ID" \
    -e EAB_PREPARE_AHEAD="${PREPARE_AHEAD:-1}" -e EAB_PREPARE_WORKERS="${PREPARE_WORKERS:-1}" \
    -e EAB_RELEASE_FILE_HOSTS="${RELEASE_FILE_HOSTS:-}" \
    -e RELEASE_DISTRIBUTION=name -e RELEASE_NODE="${NAME//-/_}@127.0.0.1" \
    -e ERL_EPMD_ADDRESS=127.0.0.1 -e ERL_EPMD_PORT="$EPMD_PORT" \
    -e 'ERL_AFLAGS=-kernel inet_dist_use_interface {127,0,0,1}' \
    -v "$CTL/data:$CTL/data" -v "$CTL/data:/data" -v "$CTL/tasks:$CTL/tasks" -v "$SOURCES:$SOURCES:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE" > /dev/null
  wait_up
  ;;
rpc) rpc "${2:?ELIXIR}" ;;
stop)
  mkdir -p "$CTL/logs"
  docker logs "$NAME" > "$CTL/logs/controller.log" 2>&1 || true
  docker stop "$NAME" > /dev/null
  echo "$NAME: stopped $(date -Is)"
  ;;
start) docker start "$NAME" > /dev/null; wait_up ;;
*) echo "unknown command $cmd"; exit 2 ;;
esac
