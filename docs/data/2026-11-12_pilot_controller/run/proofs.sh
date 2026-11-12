#!/usr/bin/env bash
# proofs.sh: the three proofs that a started controller answers (run on the machine; controller.sh up came first).
# Environment: WORK, RUN, IMAGE, NAME as for controller.sh; TASK (a task folder in the one format to import).
set -euo pipefail
: "${WORK:?}" "${TASK:?TASK=<a task folder>}"
RUN=${RUN:-$(cd "$(dirname "$0")" && pwd)}
NAME=${NAME:-factory}
C="$RUN/controller.sh"
echo "--- (a) the controller answers; its inventory holds no task"
"$C" rpc 'IO.inspect(Eab.Inventory.all())'
echo "--- (b) docker inside the controller is the wrapper"
"$C" rpc 'IO.inspect(System.find_executable("docker"))'
echo "--- (c) a made-up task is imported and listed"
id=$(basename "$TASK")
mkdir -p "$WORK/$NAME/data/incoming"
cp -r "$TASK" "$WORK/$NAME/data/incoming/$id"
"$C" rpc 'ref = Eab.Candidates.import("/data/incoming/'"$id"'"); IO.inspect(ref); IO.inspect(Eab.Candidates.read!(ref)["id"]); IO.inspect(File.ls!("/data/incoming"))'
echo "--- the controller's container"
docker inspect "$NAME" --format 'labels={{.Config.Labels}} cpu_shares={{.HostConfig.CpuShares}} network={{.HostConfig.NetworkMode}} ports={{.NetworkSettings.Ports}}'
echo "--- listening sockets of the beam"
ss -ltnp 2>/dev/null | grep beam || true
