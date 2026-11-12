#!/usr/bin/env bash
# versions.sh: per candidate, the versions its own starting commit names beside the versions the task is built and
# checked on (dataset rules, section 2, "The database and the cache": when the image table lacks the version CI
# names, the newest version of that service the table has is used, and both are recorded), and whether the project
# uses a database at that commit at all.
#   versions.sh > versions.tsv
# Environment: RESOLVE (the toolchain resolver's lines for the candidates, resolve.exs: number, starting commit, the
# Elixir and OTP each commit names and the image the table gives them, the refusal), CLONE (a bare clone of the
# project), LISTS (the job's lists.tsv: "number list" for the candidates that use the fixed recipe), FIXED (that
# fixed recipe), TASKDIRS (space-separated folders of made task folders, to read the image and services each made
# case carries; optional).
# Prints: number, start, elixir_named, otp_named, image_resolved (the table's pair for them), recipe (template or
# fixed), image_used, postgres_ci (the image the CI file starts), postgres_used, database_client (an Ecto adapter or
# Postgres driver in mix.lock, "none" when there is none), resolver (its result and reason for the commit),
# case_image (the image in the made case.json, "-" when not made).
set -euo pipefail
: "${RESOLVE:?}" "${CLONE:?}" "${LISTS:?}" "${FIXED:?}"
tag() { sed -E 's/@sha256:.*//; s/^hexpm\/elixir://'; }
fixed_image=$(jq -r .runtime.image "$FIXED" | tag)
fixed_pg=$(jq -r '.services.postgres.image // "-"' "$FIXED" | tag)
printf 'number\tstart\telixir_named\totp_named\timage_resolved\trecipe\timage_used\tpostgres_ci\tpostgres_used\tdatabase_client\tresolver\tcase_image\n'
awk -F'\t' 'NR == 1 {for (i = 1; i <= NF; i++) c[$i] = i; next}
  {print $c["number"] "\t" $c["start_revision"] "\t" $c["elixir"] "\t" $c["otp"] "\t" $c["image"] "\t" $c["result"] ":" $c["reason"]}' "$RESOLVE" |
while IFS=$'\t' read -r number start elixir otp image result; do
  ci=$(git --git-dir="$CLONE" show "$start:.github/workflows/build-and-test.yml" 2>/dev/null || true)
  pg=$(printf '%s\n' "$ci" | sed -nE 's/^[[:space:]]*image:[[:space:]]*(postgres:[^[:space:]]+).*/\1/p' | head -n 1)
  db=$(git --git-dir="$CLONE" show "$start:mix.lock" | grep -oE '^  "(ecto_sql|postgrex|myxql|ecto_sqlite3|exqlite|tds)"' |
    tr -d ' "' | tr '\n' ',' | sed 's/,$//' || true)
  if awk -v n="$number" '$1 == n {f = 1} END {exit !f}' "$LISTS"; then
    recipe=fixed; used=$fixed_image; used_pg=$fixed_pg
  else
    recipe=template; used=$(printf '%s' "$image" | tag); used_pg=-
  fi
  case_image=-
  for d in ${TASKDIRS:-}; do
    f=$d/jola-dev-pr-$number/case.json
    if [ -f "$f" ]; then case_image=$(jq -r .runtime.image "$f" | tag); break; fi
  done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$start" "$elixir" "$otp" \
    "$(printf '%s' "$image" | tag)" "$recipe" "$used" "${pg:--}" "$used_pg" "${db:-none}" "$result" "$case_image"
done
