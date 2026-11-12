#!/usr/bin/env bash
# events_table.sh: the Docker events of events.sh as tables. Needs jq.
#   events_table.sh execs EVENTS [NAME_PREFIX]       one line per docker exec in a container whose name starts with
#                                                    NAME_PREFIX (default etf-): container, run (etf.run),
#                                                    start (UTC), seconds, exit code, command (300 characters)
#   events_table.sh containers EVENTS [NAME_PREFIX]  one line per container event other than exec: time (UTC),
#                                                    container, run, event, exit code (die), image
# INSTALLATION (optional): only the containers with that etf.installation label (the controller's installation.json).
set -euo pipefail
kind=${1:?execs|containers}
events=${2:?EVENTS}
prefix=${3:-etf-}
inst=${INSTALLATION:-}
case $kind in
execs)
  printf 'container\trun\tstarted\tseconds\texit_code\tcommand\n'
  jq -rs --arg p "$prefix" --arg i "$inst" '
    map(select((.Actor.Attributes.name // "") | startswith($p)) | select($i == "" or .Actor.Attributes["etf.installation"] == $i) | select(.Action | startswith("exec_")))
    | group_by(.Actor.Attributes.execID)
    | map({
        name: .[0].Actor.Attributes.name, run: (.[0].Actor.Attributes["etf.run"] // "-"),
        create: (map(select(.Action | startswith("exec_create: "))) | first),
        die: (map(select(.Action == "exec_die")) | first)
      })
    | map(select(.create != null))
    | sort_by(.create.timeNano)
    | .[]
    | [ .name, .run,
        (.create.time | todate),
        (if .die then (((.die.timeNano - .create.timeNano) / 1e8 | round) / 10 | tostring) else "-" end),
        (if .die then .die.Actor.Attributes.exitCode else "-" end),
        (.create.Action | sub("^exec_create: "; "") | gsub("[\t\n]"; " ") | .[0:300]) ]
    | @tsv' "$events"
  ;;
containers)
  printf 'time\tcontainer\trun\tevent\texit_code\timage\n'
  jq -r --arg p "$prefix" --arg i "$inst" '
    select((.Actor.Attributes.name // "") | startswith($p)) | select($i == "" or .Actor.Attributes["etf.installation"] == $i) | select(.Action | startswith("exec_") | not)
    | [ (.time | todate), .Actor.Attributes.name, (.Actor.Attributes["etf.run"] // "-"), .Action, (.Actor.Attributes.exitCode // "-"),
        (.Actor.Attributes.image // "-") ] | @tsv' "$events"
  ;;
*) echo "unknown kind $kind"; exit 2 ;;
esac
