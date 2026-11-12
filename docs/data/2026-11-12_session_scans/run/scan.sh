#!/usr/bin/env bash
# The session scans (factory/tools/session_scans.py) on every stored session of one project: first each case's
# dependency table from its sandbox (run/extract_sandbox.sh), then one verdict line per session and its evidence.
# Python runs only in a container with no network, reading the sessions read-only.
#
#   SESSIONS=<the sessions repository's clone> WORK=<the folder extract_sandbox.sh wrote> OUT=<output folder> \
#   TOOLS=<factory/tools> [PROJECT=axelclark__ex338] [IMAGE=python:3.12-slim-bookworm] \
#   [DOCKER_RUN_ARGS="--cpu-shares 256"] run/scan.sh
#
# Writes WORK/deps/<case>.tsv (and .json, the counts), OUT/scan.sessions.tsv, OUT/scan.evidence.tsv, OUT/scan.json.
set -euo pipefail

: "${SESSIONS:?}" "${WORK:?}" "${OUT:?}" "${TOOLS:?}"
PROJECT=${PROJECT:-axelclark__ex338}
IMAGE=${IMAGE:-python:3.12-slim-bookworm}
DOCKER_RUN_ARGS=${DOCKER_RUN_ARGS:---cpu-shares 256}
mkdir -p "$WORK/deps" "$OUT"
SESSIONS=$(cd "$SESSIONS" && pwd); WORK=$(cd "$WORK" && pwd); OUT=$(cd "$OUT" && pwd)
FACTORY=$(cd "$TOOLS/.." && pwd); TOOLS=$FACTORY/tools

py() {
  # shellcheck disable=SC2086
  docker run --rm --network none $DOCKER_RUN_ARGS --label session-scans=1 -u "$(id -u):$(id -g)" -w "$WORK" \
    -v "$FACTORY:$FACTORY:ro" -v "$SESSIONS:$SESSIONS:ro" -v "$WORK:$WORK" -v "$OUT:$OUT" "$IMAGE" "$@"
}

echo "== dependency tables"
for d in "$WORK"/sandbox/*/; do
  c=$(basename "$d")
  py python -I "$TOOLS/session_scans.py" deps-table --sandbox "$d" --out "$WORK/deps/$c.tsv" > "$WORK/deps/$c.json"
  echo "$c $(cat "$WORK/deps/$c.json")"
done

echo "== scan"
py python -I "$TOOLS/session_scans.py" scan --deps "$WORK/deps" --index "$SESSIONS/sessions.tsv" \
  --out "$OUT/scan" "$SESSIONS"/raw/"$PROJECT"/*/*/
echo "== done"
