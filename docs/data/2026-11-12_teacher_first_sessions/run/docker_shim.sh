#!/bin/sh
# docker_shim.sh: mounted as "docker" ahead of the real client in the test container's PATH (test.sh). The engine's
# Docker tests start containers themselves; this adds the installation's label and a low CPU share to each
# "docker run" and passes every other command through unchanged. The engine's code is not touched.
REAL=${SHIM_DOCKER:-/usr/bin/docker}
if [ "${1:-}" = run ]; then
  shift
  exec "$REAL" run --label "${SHIM_LABEL:-task-factory=1}" --cpu-shares "${SHIM_CPU_SHARES:-256}" "$@"
fi
exec "$REAL" "$@"
