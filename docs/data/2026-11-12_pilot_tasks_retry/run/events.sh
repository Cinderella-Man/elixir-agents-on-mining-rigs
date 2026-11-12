#!/usr/bin/env bash
# events.sh: records Docker's events for every container with the label LABEL while it runs, one JSON object per line
# in OUT/events.jsonl: the containers' create, start, die (with exitCode) and oom, and every docker exec in them
# (exec_create with its command, exec_start, exec_die with exitCode). The engine's own containers are told apart
# afterwards by their label etf.installation (the controller's DATA/installation.json). Its process id goes to
# OUT/events.pid; stop it with kill.
#   setsid nohup events.sh &
# Environment: OUT, LABEL (pascal-quants=1).
set -uo pipefail
: "${OUT:?}"
LABEL=${LABEL:-pascal-quants=1}
echo $$ > "$OUT/events.pid"
exec docker events --filter type=container --filter "label=$LABEL" --format '{{json .}}' >> "$OUT/events.jsonl"
