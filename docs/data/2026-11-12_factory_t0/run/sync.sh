#!/usr/bin/env bash
# sync.sh: copy the factory folder from this checkout to the build machine (run on the editing machine).
# Environment: HOST (an ssh destination), WORK (the folder on HOST; the copy goes to WORK/src),
# FACTORY (the local factory folder; default: ../../../../factory from this script).
# The copy keeps WORK/src/.local, where Mix keeps its downloaded dependencies and compiled files.
set -euo pipefail
: "${HOST:?HOST=<ssh destination>}" "${WORK:?WORK=<folder on HOST>}"
FACTORY=${FACTORY:-$(cd "$(dirname "$0")/../../../../factory" && pwd)}
ssh "$HOST" "mkdir -p '$WORK/src' '$WORK/run'"
rsync -a --delete --chown=1000:1000 --exclude /.local "$FACTORY/" "$HOST:$WORK/src/"
rsync -a "$(dirname "$0")/" "$HOST:$WORK/run/"
