#!/usr/bin/env bash
# controller.sh: one task factory controller on a machine whose Docker also serves a bench controller (the set-up's
# controller.sh of docs/data/2026-11-12_factory_data_mining_machine/run/, with the preparation's look-ahead and
# workers from the environment, and the model server's key file mounted read only).
#   controller.sh up     start the controller NAME: data CTL/data, task folder CTL/tasks (both writable), SOURCES (a
#                        folder of task folders to import from, read only), KEY_FILE (read only at /secrets/model_key,
#                        when set); waits until it answers rpc
#   controller.sh rpc 'ELIXIR'   evaluate one line in the running controller
#   controller.sh stop   save its log to CTL/logs/controller.log, then stop it (the container, data and image stay)
#   controller.sh start  start the stopped container again and wait until it answers
# Calls to the entry points go through the factory's own wrapper: NAME=$NAME $SRC/bin/factoryctl <command> ...
# Environment: CTL (the controller's own folder), SOURCES, IMAGE, NAME (factory), LABEL (key=value, on the container
# and on everything the engine starts or builds), CPU_SHARES (256), EPMD_PORT (4510: Erlang's port mapper, loopback
# only), HEX_CACHE_ID (the BuildKit cache id of the workspace recipe's Hex packages), PREPARE_AHEAD (1) and
# PREPARE_WORKERS (1): how many tasks a run prepares ahead and at once, KEY_FILE (optional).
# The key never enters the container's environment: start_run reads the file and passes the key as its `key` option.
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
  : "${SOURCES:?}" "${IMAGE:?}" "${HEX_CACHE_ID:?}" "${LABEL:?LABEL=<key=value>}"
  mkdir -p "$CTL/data" "$CTL/tasks" "$CTL/logs"
  key=()
  [ -n "${KEY_FILE:-}" ] && key=(-v "$KEY_FILE:/secrets/model_key:ro")
  docker run -d --name "$NAME" --label "$LABEL" --cpu-shares "$CPU_SHARES" --init --network host \
    -e EAB_DATA_DIR="$CTL/data" -e EAB_TASKS_DIR="$CTL/tasks" \
    -e EAB_DOCKER_LABELS="$LABEL" -e EAB_CPU_SHARES="$CPU_SHARES" -e EAB_HEX_CACHE_ID="$HEX_CACHE_ID" \
    -e EAB_PREPARE_AHEAD="${PREPARE_AHEAD:-1}" -e EAB_PREPARE_WORKERS="${PREPARE_WORKERS:-1}" \
    -e RELEASE_DISTRIBUTION=name -e RELEASE_NODE="${NAME//-/_}@127.0.0.1" \
    -e ERL_EPMD_ADDRESS=127.0.0.1 -e ERL_EPMD_PORT="$EPMD_PORT" \
    -e 'ERL_AFLAGS=-kernel inet_dist_use_interface {127,0,0,1}' \
    -v "$CTL/data:$CTL/data" -v "$CTL/data:/data" -v "$CTL/tasks:$CTL/tasks" -v "$SOURCES:$SOURCES:ro" \
    "${key[@]}" -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE" > /dev/null
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
