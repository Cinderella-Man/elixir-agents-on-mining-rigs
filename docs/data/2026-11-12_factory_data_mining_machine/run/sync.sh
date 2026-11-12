#!/usr/bin/env bash
# sync.sh: copy the factory folder and these scripts from the editing machine to the data-mining machine.
# Environment: CLIENT (an ssh destination), SSH_OPTS (extra ssh options, e.g. for a login that is interactive by
# default), WORK (the factory's work folder on CLIENT; the copy goes to WORK/src), RUN (where the scripts go; default
# WORK/jobs/setup/run), FACTORY (the local factory folder; default: ../../../../factory from this script).
# The copy keeps WORK/src/.local, where Mix keeps its downloaded dependencies and compiled files.
set -euo pipefail
: "${CLIENT:?CLIENT=<ssh destination>}" "${WORK:?WORK=<folder on CLIENT>}"
RUN=${RUN:-$WORK/jobs/setup/run}
FACTORY=${FACTORY:-$(cd "$(dirname "$0")/../../../../factory" && pwd)}
ssh ${SSH_OPTS:-} "$CLIENT" "mkdir -p '$WORK/src' '$RUN'"
rsync -a --delete --chown=1000:1000 --exclude /.local -e "ssh ${SSH_OPTS:-}" "$FACTORY/" "$CLIENT:$WORK/src/"
rsync -a -e "ssh ${SSH_OPTS:-}" "$(dirname "$0")/" "$CLIENT:$RUN/"
