#!/usr/bin/env bash
# The toolchain each starting commit asks for. Input on stdin: a TSV of number, merged_at, merge commit (no header).
# GIT_DIR: a clone of the project (a blob-less bare clone is enough). Output: one TSV row per pull request on stdout.
# Reads .tool-versions, mise.toml (radiator's version file since 2026; CI's setup-beam reads it), the elixir: line of
# mix.exs, the Dockerfile's version arguments, and the CI files (.github/workflows/*, .travis.yml).
set -euo pipefail
: "${GIT_DIR:?a clone of the project}"
export GIT_DIR
show() { git show "$1:$2" 2>/dev/null || true; }
join() { tr '\n' ';' | sed 's/;$//'; }
printf 'number\tstart_commit\tmerged_at\ttool_versions\tmise_toml\tmix_elixir\tdockerfile\tci_files\tci_elixir\tci_otp\tci_postgres\tci_other\n'
while IFS=$'\t' read -r number merged merge; do
  start=$(git rev-parse "$merge^1")
  tv=$(show "$start" .tool-versions | join)
  mise=$(show "$start" mise.toml | grep -E '^[[:space:]]*"?(elixir|erlang|node|postgres)' | tr -d ' "' | join || true)
  mixel=$(show "$start" mix.exs | grep -oE 'elixir: *"[^"]+"' | head -1 | sed 's/elixir: *//; s/"//g' || true)
  dock=$(show "$start" Dockerfile | grep -E '^ARG (ELIXIR|OTP|DEBIAN|UBUNTU)_VERSION=' | sed 's/^ARG //' | join || true)
  ci=$(git ls-tree --name-only "$start" .github/workflows/ 2>/dev/null | tr '\n' ' ' || true)
  if [ -n "$(git ls-tree --name-only "$start" .travis.yml)" ]; then ci="$ci.travis.yml"; fi
  body=""
  for f in $ci; do body="$body$(show "$start" "$f")"$'\n'; done
  ciel=$(printf '%s' "$body" | grep -oE "elixir(-version)?: *\[?['\"]?[0-9][0-9.x]*" | sed -E "s/.*[: ]\[?['\"]?//" | sort -u | tr '\n' ' ' || true)
  ciotp=$(printf '%s' "$body" | grep -oE "(otp(-version)?|otp_release): *\[?['\"]?[0-9][0-9.x]*" | sed -E "s/.*[: ]\[?['\"]?//" | sort -u | tr '\n' ' ' || true)
  cipg=$(printf '%s' "$body" | grep -oE "(image: *postgres[^ ]*|postgres(ql)?(:[0-9][0-9.a-z-]*| *: *['\"]?[0-9][0-9.]*))" | sort -u | tr '\n' ' ' || true)
  other=$(printf '%s' "$body" | grep -oE "(version-file: *[^ ]+|node-version[^,}]*|setup-node|chromedriver|redis|imagemagick|ffmpeg|minio|apt-get install.*)" | sort -u | tr '\n' ' ' || true)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$start" "$merged" "${tv:--}" "${mise:--}" \
    "${mixel:--}" "${dock:--}" "${ci:--}" "${ciel:--}" "${ciotp:--}" "${cipg:--}" "${other:--}"
done
