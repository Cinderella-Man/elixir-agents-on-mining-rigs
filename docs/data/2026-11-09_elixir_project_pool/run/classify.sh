#!/usr/bin/env bash
# Is a repository an application that uses the frameworks, or a library, framework or tool that others use?
# Reads, per repository, mix.exs, the root folder, lib/, apps/ and priv/repo/migrations through GitHub's GraphQL API
# (metadata and one small text file each; nothing cloned, nothing run), then classifies from those signals.
#   OUT   work folder; raw answers go to $OUT/raw
#   DATA  this data folder (reads projects.tsv, writes usage_kinds.tsv)
set -euo pipefail
: "${OUT:?}" "${DATA:?}"
mkdir -p "$OUT/raw"
tail -n +2 "$DATA/projects.tsv" | awk -F'\t' '$1 != "out:holdout" {print $2}' > "$OUT/classify.txt"
rm -f "$OUT"/raw/cl_*.json "$OUT"/clchunk_*
split -l 10 -a 3 -d "$OUT/classify.txt" "$OUT/clchunk_"
for c in "$OUT"/clchunk_*; do
  q=$(awk -F/ '{ printf "r%d: repository(owner: \"%s\", name: \"%s\") { nameWithOwner mix: object(expression: \"HEAD:mix.exs\") { ... on Blob { text } } m1: object(expression: \"HEAD:elixir/mix.exs\") { ... on Blob { text } } m2: object(expression: \"HEAD:server/mix.exs\") { ... on Blob { text } } m3: object(expression: \"HEAD:backend/mix.exs\") { ... on Blob { text } } root: object(expression: \"HEAD:\") { ... on Tree { entries { name } } } lib: object(expression: \"HEAD:lib\") { ... on Tree { entries { name } } } apps: object(expression: \"HEAD:apps\") { ... on Tree { entries { name } } } apps1: object(expression: \"HEAD:elixir/apps\") { ... on Tree { entries { name } } } mig: object(expression: \"HEAD:priv/repo/migrations\") { __typename } }\n", NR, $1, $2 }' "$c")
  f="$OUT/raw/cl_$(basename "$c").json"
  for try in 1 2 3 4; do
    gh api graphql -f query="query { $q }" > "$f" 2>/dev/null || true
    jq -e ".data" "$f" > /dev/null 2>&1 && break
    echo "{}" > "$f"; sleep 5
  done
  sleep 0.7
done
jq -r '
  .data // {} | to_entries[] | select(.value != null) | .value
  | ((.mix.text // "") + "\n" + (.m1.text // "") + "\n" + (.m2.text // "") + "\n" + (.m3.text // "")) as $mix
  | ([.root.entries[]?.name]) as $root
  | ([.lib.entries[]?.name] + [.apps.entries[]?.name] + [.apps1.entries[]?.name]) as $dirs
  | def has($re): ($mix | test($re));
    [ .nameWithOwner,
      (if ($mix | length) < 5 then "no" else "yes" end),
      (if has("package:|defp? package\\b") then "yes" else "no" end),
      ([ (if has("\\{:phoenix,") then "phoenix" else empty end),
         (if has("\\{:phoenix_live_view,") then "live_view" else empty end),
         (if has("\\{:ecto_sql,|\\{:ecto,") then "ecto" else empty end),
         (if has("\\{:ash,|\\{:ash_[a-z_]+,") then "ash" else empty end),
         (if has("\\{:nerves,") then "nerves" else empty end),
         (if has("\\{:nx,|\\{:bumblebee,|\\{:axon,") then "nx" else empty end),
         (if has("\\{:oban,") then "oban" else empty end),
         (if has("\\{:absinthe,") then "absinthe" else empty end),
         (if has("\\{:broadway") then "broadway" else empty end) ] | join(",")),
      (if ($dirs | any(test("(_web|^web|^api)$"))) then "yes" else "no" end),
      (if .mig != null then "yes" else "no" end),
      ([$root[] | select(test("^(Dockerfile.*|fly\\.toml|rel|Procfile|render\\.yaml|(docker-)?compose.*\\.ya?ml)$"; "i"))] | length) ] | @tsv
' "$OUT"/raw/cl_clchunk_*.json > "$OUT/classify_signals.tsv"

awk -F'\t' -v OFS='\t' '
  NR == FNR { mixf[$1] = $2; pkg[$1] = $3; uses[$1] = $4; web[$1] = $5; mig[$1] = $6; dep[$1] = $7; next }
  FNR == 1 { print "repo", "tier", "usage_kind", "uses", "web_folder", "migrations", "hex_package_or_package_section", "deploy_files", "stars", "merged_prs"; next }
  $1 != "out:holdout" {
    r = $2; u = uses[r]; lib = (pkg[r] == "yes" || $16 != "-")
    if ($9 == "learning_or_template") k = "learning_or_template"
    else if (lib) k = "library_framework_or_tool"
    else if (u ~ /nerves/) k = "application_nerves"
    else if (u ~ /phoenix/ && (web[r] == "yes" || mig[r] == "yes")) k = "application_web"
    else if (u ~ /phoenix|ecto|ash|nx|oban|absinthe|broadway/) k = "application_other"
    else if (mixf[r] != "yes") k = "unclear_no_root_mix"
    else k = "unpublished_tool_or_library"
    print r, $1, k, u, web[r], mig[r], (lib ? "yes" : "no"), dep[r] + 0, $3, $4
  }' "$OUT/classify_signals.tsv" "$DATA/projects.tsv" > "$DATA/usage_kinds.tsv"
