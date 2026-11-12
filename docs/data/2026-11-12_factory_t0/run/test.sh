#!/usr/bin/env bash
# test.sh: the bench's bounded correctness checks (its docs/runbook.md, "Bounded correctness checks") on the factory
# folder, in the tooling image, as the user 1000:1000 with two CPUs.
#   test.sh deps                 mix deps.get (the only step with network: Hex)
#   test.sh format               mix format --check-formatted
#   test.sh capture              print the values bench_parity_test.exs pins (parity_capture.exs)
#   test.sh unit [mix args]      MIX_ENV=test mix test --warnings-as-errors
#   test.sh docker [mix args]    the same with EAB_DOCKER_TESTS=1, the Docker socket and no network. docker_shim.sh
#                                is put ahead of the real client, so every container the tests start gets LABEL
#                                and CPU_SHARES.
# The test steps add one formatter, t0_formatter.exs, which writes one line per test (file, module, test, state,
# reason) to OUT/tests/TAG.tsv; the engine's own output is unchanged. Extra arguments go to mix test.
# Environment: WORK (SRC defaults to WORK/src, OUT to WORK/out), IMAGE (eab-tooling:dev), LABEL (key=value),
# CPU_SHARES (256), UIDGID (1000:1000), TAG (the name of this step's files; default: the step).
# Writes OUT/TAG.log and OUT/TAG.done (the exit code).
set -euo pipefail
: "${WORK:?WORK=<work folder>}" "${LABEL:?LABEL=<key=value>}"
SRC=${SRC:-$WORK/src}
OUT=${OUT:-$WORK/out}
RUN=$(cd "$(dirname "$0")" && pwd)
IMAGE=${IMAGE:-eab-tooling:dev}
CPU_SHARES=${CPU_SHARES:-256}
UIDGID=${UIDGID:-1000:1000}
step=${1:?deps|format|capture|unit|docker}
shift
TAG=${TAG:-$step}
mkdir -p "$OUT/tests"
chown "$UIDGID" "$OUT/tests"
rm -f "$OUT/$TAG.done" "$OUT/tests/$TAG.tsv"
base=(docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --cpus=2 --user "$UIDGID"
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -v "$SRC:/app" -w /app)
tests=(-e MIX_ENV=test -e T0_RESULTS="/out/$TAG.tsv" -v "$OUT/tests:/out"
  -v "$RUN/t0_formatter.exs:/opt/t0/t0_formatter.exs:ro")
mix_test=(elixir -r /opt/t0/t0_formatter.exs -S mix test --warnings-as-errors
  --formatter ExUnit.CLIFormatter --formatter T0Formatter "$@")
case $step in
deps) cmd=("${base[@]}" "$IMAGE" mix deps.get) ;;
format) cmd=("${base[@]}" "$IMAGE" mix format --check-formatted) ;;
capture) cmd=("${base[@]}" -e MIX_ENV=test -v "$RUN:/opt/t0:ro" "$IMAGE" mix run /opt/t0/parity_capture.exs) ;;
unit) cmd=("${base[@]}" "${tests[@]}" "$IMAGE" "${mix_test[@]}") ;;
docker)
  path=$(docker image inspect "$IMAGE" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^PATH=//p')
  cmd=("${base[@]}" "${tests[@]}" --network none --group-add "$(stat -c %g /var/run/docker.sock)"
    -v /var/run/docker.sock:/var/run/docker.sock -v "$RUN/docker_shim.sh:/opt/shim/docker:ro"
    -e PATH="/opt/shim:$path" -e PQ_LABEL="$LABEL" -e PQ_CPU_SHARES="$CPU_SHARES" -e EAB_DOCKER_TESTS=1
    "$IMAGE" "${mix_test[@]}")
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
rc=0
{
  date -Is
  printf '%q ' "${cmd[@]}"
  echo
  "${cmd[@]}" || rc=$?
  date -Is
} > "$OUT/$TAG.log" 2>&1
echo "$rc" > "$OUT/$TAG.done"
