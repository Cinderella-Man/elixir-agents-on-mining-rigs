#!/usr/bin/env bash
# state.sh: a read-only snapshot of the machine's Docker and load, run on the data-mining machine before and after
# each step. Prints the time, the load, free bytes on /, memory, every container, image (with its size in bytes),
# volume and network, Docker's disk use, the build cache's size, the builder's garbage-collection policy and the
# listening TCP sockets.
set -uo pipefail
echo "## time"; date -Is
echo "## load"; cat /proc/loadavg
echo "## free bytes on /"; df --output=avail -B1 / | tail -1
echo "## memory"; free -b | head -2
echo "## containers"; docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
echo "## images"; docker images --no-trunc --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | sort |
  while IFS=$'\t' read -r name id; do printf '%s\t%s\t%s\n' "$name" "$id" "$(docker image inspect "$id" --format '{{.Size}}')"; done
echo "## volumes"; docker volume ls --format '{{.Name}}'
echo "## networks"; docker network ls --format '{{.Name}}\t{{.Driver}}'
echo "## docker system df"; docker system df
echo "## build cache"; docker buildx du 2>&1 | tail -3
echo "## builder"; docker buildx inspect default 2>&1 | sed -n '/GC Policy/,$p'
echo "## listening"; ss -ltn
