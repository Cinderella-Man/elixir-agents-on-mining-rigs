#!/usr/bin/env bash
# The toolchain each starting commit asks for. Input on stdin: a TSV of number, merged_at, merge commit (no header).
# GIT_DIR: a clone of the project (a full bare clone: every candidate reads several files, and a blob-less clone would
# fetch each one separately). Output: one TSV row per pull request on stdout.
# Reads .tool-versions, mise.toml, the elixir: line of mix.exs, the Dockerfile's version arguments, and the CI files
# (.github/workflows/*, .github/actions/*/action.yml, .circleci/config.yml, .travis.yml): the Postgres and ClickHouse
# images, what CI installs (apt-get, fwup, detools, Node), and its test command. A merge commit missing from the clone
# (a pull request merged into a branch that is gone) gives a row of "missing".
set -euo pipefail
: "${GIT_DIR:?a clone of the project}"
export GIT_DIR
show() { git show "$1:$2" 2>/dev/null || true; }
join() { tr '\n' ';' | sed 's/;$//'; }
uniq_line() { sort -u | tr '\n' ' ' | sed 's/ $//'; }
printf 'number\tstart_commit\tmerged_at\ttool_versions\tmise_toml\tmix_elixir\tdockerfile\tci_files\tci_elixir_image\tci_postgres\tci_clickhouse\tci_installs\tci_test\n'
while IFS=$'\t' read -r number merged merge; do
  if ! start=$(git rev-parse -q --verify "$merge^1" 2>/dev/null); then
    printf '%s\tmissing\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\n' "$number" "$merged"
    continue
  fi
  tv=$(show "$start" .tool-versions | { grep -v '^[[:space:]]*$' || true; } | join)
  mise=$(show "$start" mise.toml | grep -E '^[[:space:]]*"?[a-z]' | grep -v '^\[' | tr -d ' "' | join || true)
  mixel=$(show "$start" mix.exs | grep -oE 'elixir: *"[^"]+"' | head -1 | sed 's/elixir: *//; s/"//g' || true)
  dock=$(show "$start" Dockerfile | grep -E '^ARG (ELIXIR|OTP|ERLANG|DEBIAN|UBUNTU|ALPINE|NODE)_VERSION=' | sed 's/^ARG //' | join || true)
  ci=$( { git ls-tree -r --name-only "$start" .github/workflows/ .github/actions/ 2>/dev/null
          git ls-tree --name-only "$start" .circleci/config.yml .travis.yml 2>/dev/null; } | grep -E '\.ya?ml$' | tr '\n' ' ' || true)
  body=""
  for f in $ci; do body="$body$(show "$start" "$f")"$'\n'; done
  exi=$(printf "%s" "$body" | grep -oE "image: *['\"]?(circleci/|cimg/|hexpm/|bitwalker/)?elixir[^ '\"]*" | sed -E "s/image: *['\"]?//" | uniq_line || true)
  pg=$(printf '%s' "$body" | grep -oE "(image: *['\"]?(cimg/|circleci/)?postgres[^ '\"]*|postgres(ql)?:[0-9][0-9.a-z-]*)" | sed -E "s/image: *['\"]?//" | uniq_line || true)
  ch=$(printf '%s' "$body" | grep -oE "(yandex|clickhouse)/clickhouse-server[^ '\"]*" | uniq_line || true)
  inst=$(printf '%s' "$body" | grep -oE "(apt-get install[^&|;\"]*|FWUP_VERSION: *['\"]?[0-9.]+|fwup_[0-9.]+|pipx? install[^&|;\"]*|node-version: *['\"]?[0-9.]+|setup-node)" \
    | sed -E 's/ +/ /g; s/ $//' | uniq_line || true)
  tst=$(printf '%s' "$body" | grep -oE "mix test[^\"'#]*" | sed -E 's/ +$//' | uniq_line || true)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$start" "$merged" "${tv:--}" "${mise:--}" \
    "${mixel:--}" "${dock:--}" "${ci:--}" "${exi:--}" "${pg:--}" "${ch:--}" "${inst:--}" "${tst:--}"
done
