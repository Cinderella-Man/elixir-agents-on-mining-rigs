#!/usr/bin/env bash
# start_e448.sh: the server for Swift GSQ-RCO IQ3_S cut to 448 experts per layer (tag iq3s-e448), through serve.sh:
# the IQ3_S server's line with this file, on the loopback at PORT_iq3s_e448. It starts only if each card in
# CARDS_iq3s_e448 (PCI bus ids) holds under FREE_MIB (500) MiB, and writes server.cmd, fit.txt, props.json and
# render.txt into $WORK/serve/iq3s-e448. ENV (default bracket.env beside this script) sets WORK, BIN, MODEL_iq3s_e448,
# CARDS_iq3s_e448, PORT_iq3s_e448 and MOUNTS_iq3s_e448 (the shards' folders, mounted at the same path).
#   bash start_e448.sh          start it (a load takes minutes; the script waits for /health)
#   bash start_e448.sh plan     write server.cmd and show the cards' memory; starts nothing
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "${ENV:-$here/bracket.env}"
bash "$here/serve.sh" "${1:-up}" iq3s-e448 "$WORK/serve/iq3s-e448" || exit
[ "${1:-up}" = up ] && cat "$WORK/serve/iq3s-e448/fit.txt"
exit 0
