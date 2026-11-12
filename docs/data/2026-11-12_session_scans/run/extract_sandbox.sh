#!/usr/bin/env bash
# Reads, for every stored session of one project, the dependency metadata of the sandbox image the session ran in:
# the workspace's mix.lock, each dependency's hex_metadata.config and the names of the dependency, build, toolchain
# and Mix-archive folders. Offline: each image runs once with no network, a read-only root and a throwaway /tmp, and
# is removed at once. One folder per case; the attempts of one case share their image.
#
#   SESSIONS=<the sessions repository's clone> WORK=<scratch folder> [PROJECT=axelclark__ex338] \
#   [DOCKER_RUN_ARGS="--cpu-shares 256"] run/extract_sandbox.sh
#
# Needs docker, jq and tar on the host. Reads raw/<project>/<case>/<attempt>/engine/<case>/runtime.json (its `image`,
# the workspace image the engine ran the attempt in). Writes WORK/sandbox/<case>/: mix.lock, deps/<dep>/
# hex_metadata.config, deps.list, build.list, elixir.list, otp.list, archives.list, image.txt.
set -euo pipefail

: "${SESSIONS:?set SESSIONS to the clone of the sessions repository}"
: "${WORK:?set WORK}"
PROJECT=${PROJECT:-axelclark__ex338}
DOCKER_RUN_ARGS=${DOCKER_RUN_ARGS:---cpu-shares 256}
# the sandbox's own folders (the factory's workspace image)
SANDBOX_WS=${SANDBOX_WS:-/workspace}
SANDBOX_ELIXIR=${SANDBOX_ELIXIR:-/usr/local/lib/elixir}
SANDBOX_OTP=${SANDBOX_OTP:-/usr/local/lib/erlang}
SANDBOX_MIX_HOME=${SANDBOX_MIX_HOME:-/opt/mix}
mkdir -p "$WORK/sandbox"

for rt in "$SESSIONS"/raw/"$PROJECT"/*/*/engine/*/runtime.json; do
  case_id=$(basename "$(dirname "$rt")")
  img=$(jq -r .image "$rt")
  [[ "$img" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "$case_id: no image in $rt" >&2; exit 1; }
  dest="$WORK/sandbox/$case_id"
  if [ -f "$dest/image.txt" ]; then
    [ "$(cat "$dest/image.txt")" = "$img" ] && continue
    echo "$case_id: two attempts ran in different images" >&2; exit 1
  fi
  docker image inspect "$img" > /dev/null || { echo "$case_id: image $img is gone" >&2; exit 1; }
  rm -rf "$dest.part" && mkdir -p "$dest.part"
  # shellcheck disable=SC2086
  docker run --rm --network none --read-only --tmpfs /tmp $DOCKER_RUN_ARGS --label session-scans=1 \
    --entrypoint sh "$img" -c '
      set -e
      cd "$1"; t=$(mktemp -d)
      ls -1 deps > "$t/deps.list"
      ls -1 "_build/${MIX_ENV:-test}/lib" > "$t/build.list" 2>/dev/null || : > "$t/build.list"
      ls -1 "$2/lib" > "$t/elixir.list"
      ls -1 "$3/lib" > "$t/otp.list"
      ls -1 "$4/archives" > "$t/archives.list" 2>/dev/null || : > "$t/archives.list"
      set -- mix.lock $(ls deps/*/hex_metadata.config 2>/dev/null)
      tar -cf - "$@" -C "$t" deps.list build.list elixir.list otp.list archives.list
    ' sh "$SANDBOX_WS" "$SANDBOX_ELIXIR" "$SANDBOX_OTP" "$SANDBOX_MIX_HOME" | tar -xf - -C "$dest.part"
  echo "$img" > "$dest.part/image.txt"
  mv "$dest.part" "$dest"
  echo "$case_id $(wc -l < "$dest/deps.list") dependency folders, $(ls "$dest"/deps/*/hex_metadata.config | wc -l) with Hex metadata"
done
