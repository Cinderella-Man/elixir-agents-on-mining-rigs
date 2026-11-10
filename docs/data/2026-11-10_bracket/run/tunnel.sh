#!/usr/bin/env bash
# tunnel.sh: on the machine that runs the bench's dashboard, keep 127.0.0.1:PORT forwarded to the same port on the
# model host's loopback (where serve.sh's proxies listen), so the dashboard's endpoint is http://127.0.0.1:PORT and
# nothing on the model host is open to a network. Starts again when the connection ends.
#   SERVER_SSH="<ssh destination of the model host>" PORTS="18211 18221" \
#     setsid -f nohup bash tunnel.sh > tunnel.log 2>&1 < /dev/null
# SERVER_SSH may hold ssh options before the destination. Writes its process id to tunnel.pid beside the log.
set -uo pipefail
: "${SERVER_SSH:?SERVER_SSH=<ssh destination of the model host>}"
PORTS=${PORTS:-18211 18221}
forwards=()
for p in $PORTS; do forwards+=(-L "127.0.0.1:$p:127.0.0.1:$p"); done
echo $$ > "$(dirname "$0")/tunnel.pid"
while :; do
  echo "$(date -Is) forwarding $PORTS"
  # shellcheck disable=SC2086
  ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "${forwards[@]}" $SERVER_SSH
  echo "$(date -Is) the connection ended ($?); again in 5 s"
  sleep 5
done
