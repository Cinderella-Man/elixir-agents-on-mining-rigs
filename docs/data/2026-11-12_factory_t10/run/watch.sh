#!/usr/bin/env bash
# watch.sh: records every container that starts with the label LABEL while it runs: its name, its labels, its CPU share
# and its image, one line per container in OUT/containers.tsv. The engine's containers are told apart afterwards by
# their label etf.installation (the controller's DATA/installation.json). Stop it with kill.
#   watch.sh &
# Environment: OUT, LABEL (pascal-quants=1).
set -uo pipefail
: "${OUT:?}"
LABEL=${LABEL:-pascal-quants=1}
docker events --filter type=container --filter event=start --filter "label=$LABEL" --format '{{.Actor.ID}}' |
  while read -r id; do
    docker inspect "$id" --format \
      '{{.Created}}	{{.Name}}	{{index .Config.Labels "etf.installation"}}	{{index .Config.Labels "etf.run"}}	{{index .Config.Labels "pascal-quants"}}	{{.HostConfig.CpuShares}}	{{.Config.Image}}' \
      >> "$OUT/containers.tsv" 2>/dev/null
  done
