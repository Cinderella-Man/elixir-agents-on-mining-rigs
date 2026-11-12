#!/bin/sh
# docker_shim.sh: mounted as "docker" ahead of the real client in the test container's PATH (test.sh). The engine's
# Docker tests start containers themselves; this adds the machine's label and a low CPU share to each "docker run"
# and passes every other command through unchanged. The engine's code is not touched.
REAL=${PQ_DOCKER:-/usr/bin/docker}
if [ "${1:-}" = run ]; then
  shift
  exec "$REAL" run --label "${PQ_LABEL:?}" --cpu-shares "${PQ_CPU_SHARES:-256}" "$@"
fi
exec "$REAL" "$@"
