#!/usr/bin/env bash
# versions.sh: per candidate, the versions its starting commit names and the versions its task was built and checked
# on (rules, section 2: when the factory's table lacks the database version CI names, the task runs on the newest
# version the table has, and both are recorded).
#   versions.sh <number> ... > versions.tsv
# Environment: CLONE (a bare clone of the project), CENSUS (the census table: the merge commit in column 10), TASKDIR
# (the controller's task folder; a missing folder gives "-"). Needs git and jq.
# Prints: number, start, tool_versions (the .tool-versions elixir and erlang lines), ci_elixir_otp (the CI workflow's
# ELIXIR_VERSION/OTP_VERSION), ci_postgres (the image the CI workflow starts), elixir_otp_used and postgres_used (from
# the task's case.json image tags), recipe (template: the resolver read the commit; fixed: the fixed-version recipe).
set -euo pipefail
: "${CLONE:?}" "${CENSUS:?}" "${TASKDIR:?}"
printf 'number\tstart\ttool_versions\tci_elixir_otp\tci_postgres\telixir_otp_used\tpostgres_used\trecipe\n'
for n in "$@"; do
  merge=$(awk -F'\t' -v n="$n" '$1 == n {print $10}' "$CENSUS")
  start=$(git --git-dir="$CLONE" rev-parse "$merge^1")
  tv=$( (git --git-dir="$CLONE" show "$start:.tool-versions" 2>/dev/null || true) | awk '{printf "%s%s %s", (NR > 1 ? "; " : ""), $1, $2}')
  ci=$(git --git-dir="$CLONE" show "$start:.github/workflows/ci.yml" 2>/dev/null || true)
  ce=$(printf '%s\n' "$ci" | sed -nE 's/^ *ELIXIR_VERSION: *([0-9.]+).*/\1/p' | head -1)
  co=$(printf '%s\n' "$ci" | sed -nE 's/^ *OTP_VERSION: *([0-9.]+).*/\1/p' | head -1)
  cp=$(printf '%s\n' "$ci" | sed -nE 's/^ *image: *(postgres:[^ ]+).*/\1/p' | head -1)
  c=$TASKDIR/backend-pr-$n/case.json
  if [ -f "$c" ]; then
    used=$(jq -r '.runtime.image | capture("elixir:(?<e>[0-9.]+)-erlang-(?<o>[0-9.]+)-") | "\(.e)/\(.o)"' "$c")
    pg=$(jq -r '.services.postgres.image // "-" | sub("@.*"; "")' "$c")
    if jq -e '.toolchain' "$TASKDIR/backend-pr-$n/provenance.json" > /dev/null 2>&1; then r=template; else r=fixed; fi
  else
    used=-; pg=-; r=-
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$start" "${tv:--}" "${ce:--}/${co:--}" "${cp:--}" "$used" "$pg" "$r"
done
