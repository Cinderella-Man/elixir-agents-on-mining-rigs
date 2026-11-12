#!/usr/bin/env bash
# capture.sh: run job T0's parity_capture.exs and this job's parity_capture_feature.exs in the unchanged copy of the
# bench's engine (this repository's commit 470301e), in a scratch folder of the build machine.
# Before it, on the editing machine:
#   git archive 470301e factory | ssh "$HOST" tar -x -C "$WORK/t5/copy470"
# Environment: WORK (the work folder of job T0's scripts), LABEL (key=value), IMAGE (eab-tooling:dev),
# CPU_SHARES (256), UIDGID (1000:1000). The copy's Hex packages are fetched by `mix deps.get` from its own mix.lock
# after the work folder's `.local` is copied in to reuse what is already there. That step and the compile of the
# dependencies have network; the two captures run without.
# Writes WORK/t5/out/capture_deps.log, capture_t0.txt, capture_feature.txt and capture.done (the exit code).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
IMAGE=${IMAGE:-eab-tooling:dev}
CPU_SHARES=${CPU_SHARES:-256}
UIDGID=${UIDGID:-1000:1000}
COPY=$WORK/t5/copy470/factory
OUT=$WORK/t5/out
RUN=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
rm -f "$OUT/capture.done"
[ -d "$COPY/.local" ] || cp -a "$WORK/src/.local" "$COPY/.local"
chown -R "$UIDGID" "$COPY"
base=(docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --cpus=2 --user "$UIDGID"
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -e MIX_ENV=test -v "$COPY:/app" -w /app
  -v "$WORK/run:/opt/t0:ro" -v "$RUN:/opt/t5:ro")
# `mix deps.get` ends with exit code 1 when a locked package has a published advisory (the copy's Bandit has), after
# fetching everything; its code is logged, and a missing package would stop the next step instead.
"${base[@]}" "$IMAGE" mix deps.get > "$OUT/capture_deps.log" 2>&1 || echo "deps.get exit $?" >> "$OUT/capture_deps.log"
rc=0
{
  # The copy's test-only `lazy_html` downloads its precompiled library while it compiles, so this step has network.
  "${base[@]}" "$IMAGE" mix deps.compile >> "$OUT/capture_deps.log" 2>&1 &&
    "${base[@]}" --network none "$IMAGE" mix run /opt/t0/parity_capture.exs > "$OUT/capture_t0.txt" 2> "$OUT/capture_t0.err" &&
    "${base[@]}" --network none "$IMAGE" mix run /opt/t5/parity_capture_feature.exs > "$OUT/capture_feature.txt" 2> "$OUT/capture_feature.err"
} || rc=$?
echo "$rc" > "$OUT/capture.done"
