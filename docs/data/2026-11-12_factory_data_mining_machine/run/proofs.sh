#!/usr/bin/env bash
# proofs.sh: the three proofs that a started controller works (job P2's, through the entry points of section 9):
# (a) it answers and its inventory is empty; (b) the docker it calls, and the labels, share and Hex cache id the
# engine adds; (c) an import of a made-up task is accepted. Then the controller's container and the BEAM's sockets.
# Environment: CTL, NAME, SRC (the factory folder: bin/factoryctl and the made-up task), TASK (a made-up task id under
# SRC/test/support/tasks; default ledgerette-pr-1).
set -euo pipefail
: "${CTL:?}" "${NAME:?}" "${SRC:?}"
TASK=${TASK:-ledgerette-pr-1}
C="$(dirname "$0")/controller.sh"
echo "--- (a) the controller answers; its inventory holds no task"
"$C" rpc 'IO.inspect(Eab.Inventory.all())'
NAME=$NAME "$SRC/bin/factoryctl" status
echo "--- (b) the docker it calls; what the engine adds to each docker run and build; the Hex cache id"
"$C" rpc 'IO.inspect(System.find_executable("docker")); IO.inspect(Eab.DockerSettings.run_args()); IO.inspect(Eab.DockerSettings.build_args()); IO.inspect(Eab.DockerSettings.hex_cache_id())'
echo "--- (c) a made-up task is imported"
mkdir -p "$CTL/data/incoming"
rm -rf "${CTL:?}/data/incoming/$TASK"
cp -r "$SRC/test/support/tasks/$TASK" "$CTL/data/incoming/$TASK"
NAME=$NAME "$SRC/bin/factoryctl" import "$CTL/data/incoming"
ls "$CTL/tasks"
"$C" rpc 'IO.inspect(Eab.Inventory.all())'
echo "--- the controller's container"
docker inspect "$NAME" --format 'labels={{.Config.Labels}} cpu_shares={{.HostConfig.CpuShares}} network={{.HostConfig.NetworkMode}} ports={{.NetworkSettings.Ports}} mounts={{range .Mounts}}{{.Type}}:{{.Source}}->{{.Destination}} {{end}}'
echo "--- listening sockets of the controller's BEAM and its port mapper"
ss -ltnp | grep -E "beam|epmd"
