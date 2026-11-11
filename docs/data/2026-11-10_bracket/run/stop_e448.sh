#!/usr/bin/env bash
# stop_e448.sh: stop the iq3s-e448 server; serve.sh saves its log to $WORK/serve/iq3s-e448/server.log and removes the
# container. ENV as in start_e448.sh.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "${ENV:-$here/bracket.env}"
bash "$here/serve.sh" down iq3s-e448 "$WORK/serve/iq3s-e448"
