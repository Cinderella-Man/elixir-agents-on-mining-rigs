#!/usr/bin/env bash
# toolchain_image.sh: look up one image for the toolchain table (config/toolchain_images.json) at Docker Hub and
# print the line to add. Nothing is pulled; the table grows only by lines a person has read. The bundle maker never
# runs this script: a pair missing from the table is refused (no_image:<elixir>/<otp>).
#   toolchain_image.sh elixir <elixir> <otp>    the newest hexpm/elixir:<elixir>-erlang-<otp>-<base>-<date>, the bases
#                                               tried in order: ubuntu-noble, ubuntu-jammy, ubuntu-focal,
#                                               debian-bookworm, debian-bullseye, debian-buster
#   toolchain_image.sh postgres <major>         the newest postgres:<major>.<minor>-alpine
#   toolchain_image.sh clickhouse <version>     the newest clickhouse/clickhouse-server:<version>[.<n>...]
#   toolchain_image.sh redis <version>          redis:<version>-alpine (the tag itself: Redis keeps one tag per minor
#                                               version, moved to each patch release)
# Each image is pinned by the digest Docker Hub lists for its tag. Needs curl and jq.
set -euo pipefail
kind=${1:?elixir|postgres|clickhouse|redis}
hub=https://hub.docker.com/v2/namespaces

# tags REPO_NAMESPACE REPO NAME_FILTER: every "name digest" line Docker Hub lists for tags containing NAME_FILTER.
tags() {
  local url="$hub/$1/repositories/$2/tags?page_size=100&name=$3"
  while [ -n "$url" ] && [ "$url" != null ]; do
    page=$(curl -fsS "$url")
    printf '%s' "$page" | jq -r '.results[] | select(.digest != null) | "\(.name) \(.digest)"'
    url=$(printf '%s' "$page" | jq -r '.next')
  done
}

case $kind in
elixir)
  elixir=${2:?elixir version}
  otp=${3:?otp version}
  for base in ubuntu-noble ubuntu-jammy ubuntu-focal debian-bookworm debian-bullseye debian-buster; do
    prefix="$elixir-erlang-$otp-$base-"
    line=$(tags hexpm elixir "$prefix" | awk -v p="$prefix" 'index($1, p) == 1 && substr($1, length(p) + 1) ~ /^[0-9]{8}(\.[0-9]+)?$/' |
      sort -V | tail -n 1)
    if [ -n "$line" ]; then
      set -- $line
      printf '{"elixir": "%s", "otp": "%s", "image": "hexpm/elixir:%s@%s"}\n' "$elixir" "$otp" "$1" "$2"
      exit 0
    fi
  done
  echo "no hexpm/elixir tag for Elixir $elixir with OTP $otp" >&2
  exit 1
  ;;
postgres)
  major=${2:?major version}
  line=$(tags library postgres "$major." | awk -v m="$major" '$1 ~ ("^" m "\\.[0-9]+-alpine$")' | sort -V | tail -n 1)
  [ -n "$line" ] || { echo "no postgres:$major.<minor>-alpine tag" >&2; exit 1; }
  set -- $line
  printf '{"version": "%s", "image": "postgres:%s@%s"}\n' "$major" "$1" "$2"
  ;;
clickhouse)
  version=${2:?version}
  line=$(tags clickhouse clickhouse-server "$version" |
    awk -v v="$version" 'index($1, v) == 1 && substr($1, length(v) + 1) ~ /^(\.[0-9]+)*$/' | sort -V | tail -n 1)
  [ -n "$line" ] || { echo "no clickhouse/clickhouse-server tag for $version" >&2; exit 1; }
  set -- $line
  printf '{"version": "%s", "image": "clickhouse/clickhouse-server:%s@%s"}\n' "$version" "$1" "$2"
  ;;
redis)
  version=${2:?version}
  line=$(tags library redis "$version-alpine" | awk -v t="$version-alpine" '$1 == t' | head -n 1)
  [ -n "$line" ] || { echo "no redis:$version-alpine tag" >&2; exit 1; }
  set -- $line
  printf '{"version": "%s", "image": "redis:%s@%s"}\n' "$version" "$1" "$2"
  ;;
*) echo "unknown kind $kind" >&2; exit 2 ;;
esac
