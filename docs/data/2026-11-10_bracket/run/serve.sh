#!/usr/bin/env bash
# serve.sh: one llama-server for one file of the bracket, in a container on that file's cards. The bench's dashboard
# connects to the server's own port (through tunnel.sh when it runs on another machine).
#   serve.sh up TAG DIR      start it; DIR gets server.cmd (the line as run), fit.txt (the cards' memory after
#                            loading), props.json and render.txt (the chat template's output for one message: the
#                            reasoning-effort line)
#   serve.sh down TAG DIR    save server.log into DIR and remove the container
#   serve.sh plan TAG DIR    write DIR/server.cmd (the line up would run) and show the cards' memory; starts nothing
# Environment: BIN (llama-server: Miner Llama v3, 1551f5fe1), MODEL_<TAG> (the file's first shard), GPUS_<TAG> (docker
# device list) or CARDS_<TAG> (PCI bus ids as nvidia-smi prints them, resolved to UUIDs and checked one by one),
# PORT_<TAG> (the server, on the loopback), MOUNTS (folders the server reads, mounted at the same path; MOUNTS_<TAG>
# replaces it for one file), WORK (JIT defaults to WORK/jit: the kernels the cards compile from the build's PTX), CTX (262144, the
# bench's window), SERVER_ARGS (the line below), SERVER_IMAGE (nvidia/cuda:12.9.2-devel-ubuntu24.04), LABEL,
# CPU_SHARES, PREFIX (container names), LOAD_TIMEOUT_S (1800), FREE_MIB (a card counts as free below this much
# used memory, 500).
# PROXY=1 also starts the sister repo's logging proxy (AGENT_CHECK = the folder with proxy.py and common.py,
# PROXY_IMAGE = any image with python3) on PORT + 1, writing DIR/proxy.jsonl and its bodies. The bench's memory
# collector cannot sample through it: it looks for the GPU process in the cgroup of the process that listens on the
# endpoint's port, and the proxy runs in a container of its own. The bench keeps every request, event stream and
# token count per case itself, so the runs go to the server's port.
# The server line is the release preset's sampling and template flags at the bench's window with one slot. It leaves
# out the preset's draft, its nine-card split and its Pascal switches: those are the rig's speed settings.
# -fit off: a file that does not fit at the window stops the load instead of loading with a smaller window.
set -uo pipefail
cmd=${1:?up|down}; tag=${2:?TAG}; dir=${3:?DIR}
: "${WORK:?}" "${BIN:?BIN=<llama-server>}"
vt=${tag//-/_}  # the variables' names: the tag with each - as _
v=MODEL_$vt; MODEL=${!v:?MODEL_$vt=<first shard>}
v=PORT_$vt; PORT=${!v:?PORT_$vt=<port>}
v=MOUNTS_$vt; MOUNTS=${!v:-${MOUNTS:-}}
v=CARDS_$vt; CARDS=${!v:-}
v=GPUS_$vt; GPUS=${!v:-}
[ -n "$CARDS$GPUS" ] || { echo "set CARDS_$vt=<PCI bus ids> or GPUS_$vt=<docker device list>"; exit 2; }
PROXY=${PROXY:-0}
PROXY_PORT=$((PORT + 1))
CTX=${CTX:-262144}
SERVER_ARGS=${SERVER_ARGS:--ngl 99 -fa on -c $CTX -np 1 --ctx-checkpoints 4 --cache-ram 0 --jinja --reasoning-format deepseek --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 -b 2048 -ub 512 -fit off --metrics --no-webui}
IMAGE=${SERVER_IMAGE:-nvidia/cuda:12.9.2-devel-ubuntu24.04}
PROXY_IMAGE=${PROXY_IMAGE:-agent-check:0.87.1}
LABEL=${LABEL:-pascal-quants=1}
CPU_SHARES=${CPU_SHARES:-256}
PREFIX=${PREFIX:-bracket}
JIT=${JIT:-$WORK/jit}
LOAD_TIMEOUT_S=${LOAD_TIMEOUT_S:-1800}
FREE_MIB=${FREE_MIB:-500}
SRV=$PREFIX-srv-$tag
PRX=$PREFIX-proxy-$tag
mkdir -p "$dir" "$JIT"

down() {
  docker logs "$SRV" > "$dir/server.log" 2>&1
  if docker inspect "$PRX" > /dev/null 2>&1; then docker logs "$PRX" > "$dir/proxy.out" 2>&1; fi
  docker rm -f "$PRX" "$SRV" > /dev/null 2>&1
}

if [ "$cmd" = down ]; then down; exit 0; fi
[ "$cmd" = up ] || [ "$cmd" = plan ] || { echo "unknown command $cmd"; exit 2; }

if [ -n "$CARDS" ]; then
  # each bus id once, matched on its end (0A:00.0 or 00000000:0A:00.0), in the order given
  GPUS=; busy=0
  for b in ${CARDS//,/ }; do
    row=$(nvidia-smi --query-gpu=pci.bus_id,uuid,memory.used --format=csv,noheader,nounits \
      | awk -F', ' -v b="${b^^}" 'length($1) >= length(b) && substr(toupper($1), length($1) - length(b) + 1) == b')
    [ "$(printf '%s\n' "$row" | grep -c .)" = 1 ] || { echo "$tag: no single card at bus id $b"; exit 1; }
    IFS=', ' read -r bus uuid used <<< "$row"
    echo "$tag: card $bus holds $used MiB"
    [ "$used" -lt "$FREE_MIB" ] || busy=1
    GPUS=${GPUS:+$GPUS,}$uuid
  done
  [ "$busy" = 0 ] || [ "$cmd" = plan ] || { echo "$tag: a card of its set holds $FREE_MIB MiB or more; not started"; exit 1; }
elif [ "$cmd" = up ]; then
  for used in $(nvidia-smi -i "$GPUS" --query-gpu=memory.used --format=csv,noheader,nounits); do
    [ "$used" -lt "$FREE_MIB" ] || { echo "$tag: a card of its set holds $used MiB before the load"; exit 1; }
  done
fi
mounts=()
for m in ${MOUNTS:-}; do mounts+=(-v "$m:$m"); done
# shellcheck disable=SC2086
set -- docker run -d --init --name "$SRV" --label "$LABEL" --cpu-shares "$CPU_SHARES" --network host \
  --gpus "\"device=$GPUS\"" "${mounts[@]}" -v "$JIT:$JIT" -e "CUDA_CACHE_PATH=$JIT" "$IMAGE" \
  "$BIN" -m "$MODEL" $SERVER_ARGS --host 127.0.0.1 --port "$PORT"
echo "$(date -Is) $*" > "$dir/server.cmd"
if [ "$cmd" = plan ]; then echo "$tag: planned, not started: $dir/server.cmd"; exit 0; fi
docker rm -f "$PRX" "$SRV" > /dev/null 2>&1
"$@" > /dev/null || { echo "$tag: the server container did not start"; exit 1; }
t0=$SECONDS
until curl -sf "http://127.0.0.1:$PORT/health" 2> /dev/null | grep -q '"ok"'; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$SRV" 2> /dev/null)" != true ]; then
    echo "$tag: the server ended while loading: $(docker logs "$SRV" 2>&1 | tail -n 4 | tr '\n' ' ')"
    down; exit 1
  fi
  [ $((SECONDS - t0)) -lt "$LOAD_TIMEOUT_S" ] || { echo "$tag: no /health in $LOAD_TIMEOUT_S s"; down; exit 1; }
  sleep 5
done
{ date -Is; nvidia-smi -i "$GPUS" --query-gpu=pci.bus_id,name,memory.used,memory.total --format=csv,noheader; } > "$dir/fit.txt"
curl -sf "http://127.0.0.1:$PORT/props" > "$dir/props.json"
curl -sf "http://127.0.0.1:$PORT/apply-template" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"ping"}]}' > "$dir/render.txt"
if [ "$PROXY" != 1 ]; then echo "$tag: ready on 127.0.0.1:$PORT"; exit 0; fi

: "${AGENT_CHECK:?AGENT_CHECK=<folder with proxy.py>}"
docker run -d --name "$PRX" --label "$LABEL" --cpu-shares "$CPU_SHARES" --network host \
  -v "$AGENT_CHECK:$AGENT_CHECK:ro" -v "$dir:$dir" "$PROXY_IMAGE" python3 -I "$AGENT_CHECK/proxy.py" \
  --listen "127.0.0.1:$PROXY_PORT" --upstream "127.0.0.1:$PORT" --log "$dir/proxy.jsonl" > /dev/null \
  || { echo "$tag: the proxy container did not start"; down; exit 1; }
for _ in $(seq 20); do
  curl -sf "http://127.0.0.1:$PROXY_PORT/health" 2> /dev/null | grep -q '"ok"' \
    && { echo "$tag: ready on 127.0.0.1:$PORT, proxy on 127.0.0.1:$PROXY_PORT"; exit 0; }
  sleep 1
done
echo "$tag: the proxy does not answer: $(docker logs "$PRX" 2>&1 | tail -n 3 | tr '\n' ' ')"
down; exit 1
