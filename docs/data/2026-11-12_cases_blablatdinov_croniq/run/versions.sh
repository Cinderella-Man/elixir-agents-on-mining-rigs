#!/usr/bin/env bash
# versions.sh: per candidate, the versions its own starting commit names beside the versions the task is built and
# checked on (dataset rules, section 2, "The database and the cache": when the image table lacks the version CI
# names, the newest version of that service the table has is used, and both are recorded).
#   versions.sh > versions.tsv
# Environment: RESOLVE (the toolchain resolver's lines for the candidates, resolve.exs: number, starting commit, the
# Elixir and OTP each commit names and the image the table gives them, the refusal), CLONE (a bare clone of the
# project), RECIPE (the project's recipe: the image and services used).
# Prints: number, start, elixir_named, otp_named, image_resolved (the table's pair for them), image_used, postgres_ci
# (the image the CI file starts), postgres_used, redis_ci, redis_client (a Redis client in mix.exs), redis_used,
# resolver (its result and reason for the commit).
set -euo pipefail
: "${RESOLVE:?}" "${CLONE:?}" "${RECIPE:?}"
tag() { sed -E 's/@sha256:.*//; s/^hexpm\/elixir://'; }
used_image=$(jq -r .runtime.image "$RECIPE" | tag)
used_pg=$(jq -r '.services.postgres.image // "-"' "$RECIPE" | tag)
used_redis=$(jq -r '.services.redis.image // "-"' "$RECIPE" | tag)
printf 'number\tstart\telixir_named\totp_named\timage_resolved\timage_used\tpostgres_ci\tpostgres_used\tredis_ci\tredis_client\tredis_used\tresolver\n'
awk -F'\t' 'NR == 1 {for (i = 1; i <= NF; i++) c[$i] = i; next}
  {print $c["number"] "\t" $c["start_revision"] "\t" $c["elixir"] "\t" $c["otp"] "\t" $c["image"] "\t" $c["result"] ":" $c["reason"]}' "$RESOLVE" |
while IFS=$'\t' read -r number start elixir otp image result; do
  ci=$(git --git-dir="$CLONE" show "$start:.github/workflows/pr-check.yml" 2>/dev/null || true)
  pg=$(printf '%s\n' "$ci" | sed -nE 's/^[[:space:]]*image:[[:space:]]*(postgres:[^[:space:]]+).*/\1/p' | head -n 1)
  rd=$(printf '%s\n' "$ci" | sed -nE 's/^[[:space:]]*image:[[:space:]]*(redis:[^[:space:]]+).*/\1/p' | head -n 1)
  client=$(git --git-dir="$CLONE" show "$start:mix.exs" | grep -oE '\{:(redix|exredis|eredis|redis),' | tr -d '{:,' | head -n 1 || true)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$start" "$elixir" "$otp" \
    "$(printf '%s' "$image" | tag)" "$used_image" "${pg:--}" "$used_pg" "${rd:--}" "${client:--}" "$used_redis" "$result"
done
