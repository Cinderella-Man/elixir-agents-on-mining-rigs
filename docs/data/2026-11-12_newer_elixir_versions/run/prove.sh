#!/usr/bin/env bash
# prove.sh: the three proofs for one line of the toolchain table, each in its own container from the pinned image,
# as the user 1000:1000 with its own MIX_HOME and HEX_HOME (the engine's workspace user has id 1000):
#   a. the image starts: `true` exits 0;
#   b. it is the pair: `elixir --version` names "Elixir <elixir> " and the OTP release's OTP_VERSION file is <otp>;
#   c. Hex installs the way the engine does (lib/eab/fixtures.ex, hex_install/1 for Elixir 1.14 and newer):
#      `mix local.hex 2.5.3 --force && mix local.rebar --force`, then `mix hex.info` names Hex 2.5.3.
# The hexpm/elixir images hold no CA certificates; the engine's recipe installs the base's ca-certificates package
# before Hex. CA=host (the default) mounts this machine's bundle, /etc/ssl/certs, read only; CA=apt installs the
# package in the container as root first, as the recipe does (it downloads the base's package lists).
# Usage: prove.sh <elixir> <otp> <image>. The image is pulled first when Docker does not hold it.
# Environment: OUT, LABEL (key=value), CPU_SHARES (256), CA (host or apt). Writes OUT/proofs/<elixir>_<otp>[_apt].log
# and prints "<elixir>\t<otp>\t<image>\t<pull>\t<a>\t<b>\t<c>\t<detail>" (each proof ok or failed).
set -uo pipefail
: "${OUT:?}" "${LABEL:?LABEL=<key=value>}"
CPU_SHARES=${CPU_SHARES:-256}
CA=${CA:-host}
elixir=${1:?elixir} otp=${2:?otp} image=${3:?image}
mkdir -p "$OUT/proofs"
log="$OUT/proofs/${elixir}_${otp}$([ "$CA" = apt ] && echo _apt).log"
base=(docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES")
user=(--user 1000:1000 -e HOME=/tmp -e MIX_HOME=/tmp/mix -e HEX_HOME=/tmp/hex)
hex='mix local.hex 2.5.3 --force && mix local.rebar --force && mix hex.info'
: > "$log"
step() { # step NAME COMMAND...: runs COMMAND, its output to the log, returns its exit code
  local name=$1 rc
  shift
  printf '== %s %s\n' "$name" "$(date -Is)" >> "$log"
  "$@" >> "$log" 2>&1
  rc=$?
  printf '== %s exit %s %s\n' "$name" "$rc" "$(date -Is)" >> "$log"
  return "$rc"
}
pull=ok a=failed b=failed c=failed detail=-
if ! docker image inspect "$image" > /dev/null 2>&1; then
  step pull docker pull "$image" || pull=failed
else
  pull=present
fi
if [ "$pull" != failed ]; then
  step a "${base[@]}" "${user[@]}" "$image" true && a=ok
  step b "${base[@]}" "${user[@]}" "$image" sh -c 'elixir --version 2>/dev/null | grep -E "^(Erlang/OTP|Elixir) "; root=$(dirname "$(dirname "$(readlink -f "$(command -v erl)")")"); for f in "$root"/releases/*/OTP_VERSION; do printf "OTP_VERSION %s\n" "$(cat "$f")"; done'
  got_otp=$(sed -n 's/^OTP_VERSION //p' "$log" | head -n 1)
  got_elixir=$(sed -n 's/^Elixir \([^ ]*\) .*/\1/p' "$log" | head -n 1)
  if [ "$got_elixir" = "$elixir" ] && [ "$got_otp" = "$otp" ]; then b=ok; fi
  detail="elixir $got_elixir, otp $got_otp"
  if [ "$CA" = apt ]; then
    cmd=("${base[@]}" -e HOME=/tmp -e MIX_HOME=/tmp/mix -e HEX_HOME=/tmp/hex "$image" sh -c
      "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ca-certificates > /dev/null && mkdir -p /tmp/mix /tmp/hex && chown -R 1000:1000 /tmp/mix /tmp/hex && su -s /bin/sh -c 'HOME=/tmp MIX_HOME=/tmp/mix HEX_HOME=/tmp/hex PATH=$PATH $hex' \$(getent passwd 1000 | cut -d: -f1 || echo ubuntu)")
  else
    cmd=("${base[@]}" "${user[@]}" -v /etc/ssl/certs:/etc/ssl/certs:ro "$image" sh -c "$hex")
  fi
  if step c "${cmd[@]}"; then
    if sed -n '/^== c /,$p' "$log" | grep -q '^Hex: *2\.5\.3'; then c=ok; fi
  fi
  [ "$c" = ok ] || detail="$detail; hex: $(sed -n '/^== c /,$p' "$log" | grep -v '^==' | grep -iE 'error|fail|could not|unable' | grep -v sctp | head -n 1 | cut -c1-160)"
else
  detail="pull: $(grep -v '^==' "$log" | tail -n 1 | cut -c1-160)"
fi
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$elixir" "$otp" "$image" "$pull" "$a" "$b" "$c" "$detail"
