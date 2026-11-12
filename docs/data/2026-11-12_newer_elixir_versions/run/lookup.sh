#!/usr/bin/env bash
# lookup.sh: find the hexpm/elixir images for the toolchain table's missing pairs at Docker Hub. Nothing is pulled.
#   lookup.sh pair <elixir> <otp>        the line scripts/toolchain_image.sh prints for the exact pair, as
#                                        "<elixir>\t<otp>\tfound\t<line>"; when there is none,
#                                        "<elixir>\t<otp>\tno_image\t<the nearest>": the OTP versions of the same
#                                        major release Docker Hub has for that Elixir, and the Elixir versions it has
#                                        for that OTP
#   lookup.sh otps <elixir> [<prefix>]   the OTP versions with an image for that Elixir (those that start with
#                                        <prefix>, e.g. "27."), oldest first
#   lookup.sh elixirs <otp>              the Elixir versions with an image for that OTP, oldest first
# Only the bases toolchain_image.sh tries are counted (ubuntu-noble, ubuntu-jammy, ubuntu-focal, debian-bookworm,
# debian-bullseye, debian-buster). Docker Hub answered 403 to the later pages of some long listings;
# the listing is then cut, and the script says so on stderr. Environment: SRC (the factory folder). Needs curl and jq.
set -euo pipefail
: "${SRC:?SRC=<the factory folder>}"
hub=https://hub.docker.com/v2/namespaces/hexpm/repositories/elixir/tags
bases='ubuntu-noble|ubuntu-jammy|ubuntu-focal|debian-bookworm|debian-bullseye|debian-buster'

# names FILTER: every tag name Docker Hub lists that contains FILTER.
names() {
  local url="$hub?page_size=100&name=$1" page
  while [ -n "$url" ] && [ "$url" != null ]; do
    if ! page=$(curl -fsS "$url" 2>/dev/null); then
      echo "lookup.sh: Docker Hub refused a page of the listing for \"$1\"; the list is cut" >&2
      return 0
    fi
    printf '%s' "$page" | jq -r '.results[].name'
    url=$(printf '%s' "$page" | jq -r '.next')
  done
}

re() { printf '%s' "$1" | sed 's/\./\\./g'; }

otps() {
  names "$1-erlang-${2:-}" |
    sed -En "s/^$(re "$1")-erlang-([0-9.]+)-($bases)-[0-9]{8}(\.[0-9]+)?$/\1/p" | grep "^$(re "${2:-}")" | sort -uV
}

elixirs() {
  names "-erlang-$1-" | sed -En "s/^([0-9.]+)-erlang-$(re "$1")-($bases)-[0-9]{8}(\.[0-9]+)?$/\1/p" | sort -uV
}

case ${1:?pair|otps|elixirs} in
pair)
  elixir=${2:?elixir} otp=${3:?otp}
  if line=$("$SRC/scripts/toolchain_image.sh" elixir "$elixir" "$otp" 2>/dev/null); then
    printf '%s\t%s\tfound\t%s\n' "$elixir" "$otp" "$line"
  else
    printf '%s\t%s\tno_image\tOTP %s.x for Elixir %s: %s; Elixir for OTP %s: %s\n' "$elixir" "$otp" "${otp%%.*}" \
      "$elixir" "$(otps "$elixir" "${otp%%.*}." | tr '\n' ' ' | sed 's/ $//')" \
      "$otp" "$(elixirs "$otp" | tr '\n' ' ' | sed 's/ $//')"
  fi
  ;;
otps) otps "${2:?elixir}" "${3:-}" ;;
elixirs) elixirs "${2:?otp}" ;;
*) echo "unknown mode $1" >&2; exit 2 ;;
esac
