#!/usr/bin/env bash
# proof.sh: the engine's own labels and CPU share, with no wrapper in front of docker. Runs only
# test/eab/docker_settings_docker_test.exs in the tooling image, with the Docker socket and no network, and with
# EAB_DOCKER_LABELS=LABEL and EAB_CPU_SHARES=CPU_SHARES given to the test, which sets them as the engine's settings.
# The test prints one line per container the engine started and per image it built ("T7 container ...",
# "T7 image ..."), with their labels and shares.
# Environment: WORK (SRC defaults to WORK/src, OUT to WORK/out), IMAGE (eab-tooling:dev), LABEL (key=value),
# CPU_SHARES (256), UIDGID (1000:1000), TAG (the name of this step's files; default: proof).
# Writes OUT/TAG.log and OUT/TAG.done (the exit code).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
SRC=${SRC:-$WORK/src}
OUT=${OUT:-$WORK/out}
IMAGE=${IMAGE:-eab-tooling:dev}
CPU_SHARES=${CPU_SHARES:-256}
UIDGID=${UIDGID:-1000:1000}
TAG=${TAG:-proof}
rm -f "$OUT/$TAG.done"
cmd=(docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --cpus=2 --user "$UIDGID"
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -v "$SRC:/app" -w /app -e MIX_ENV=test
  --network none --group-add "$(stat -c %g /var/run/docker.sock)" -v /var/run/docker.sock:/var/run/docker.sock
  -e EAB_DOCKER_TESTS=1 -e EAB_DOCKER_LABELS="$LABEL" -e EAB_CPU_SHARES="$CPU_SHARES"
  "$IMAGE" mix test --warnings-as-errors test/eab/docker_settings_docker_test.exs)
rc=0
{
  date -Is
  printf '%q ' "${cmd[@]}"
  echo
  "${cmd[@]}" || rc=$?
  date -Is
} > "$OUT/$TAG.log" 2>&1
echo "$rc" > "$OUT/$TAG.done"
