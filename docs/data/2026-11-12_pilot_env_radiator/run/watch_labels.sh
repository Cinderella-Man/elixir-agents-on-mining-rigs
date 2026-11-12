#!/usr/bin/env bash
# Records the label and CPU share of every container the engine starts (names eab-*), every 2 s, until STOP exists.
# Environment: OUT (the log file), STOP (a file whose presence ends the loop).
set -u
: "${OUT:?}" "${STOP:?}"
while [ ! -e "$STOP" ]; do
  for c in $(docker ps -q --filter name=eab-); do
    docker inspect "$c" --format '{{.Name}} {{index .Config.Labels "pascal-quants"}} {{.HostConfig.CpuShares}} {{.HostConfig.NetworkMode}} {{.Config.Image}}' 2>/dev/null
  done | sort -u >> "$OUT"
  sleep 2
done
sort -u -o "$OUT" "$OUT"
