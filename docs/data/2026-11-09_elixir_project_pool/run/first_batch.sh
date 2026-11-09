#!/usr/bin/env bash
# Per repository of the first batch, from GitHub's GraphQL API (metadata and four small text files, nothing cloned,
# nothing run): language shares, the root folder's entries, the licence file's first lines, mix.exs and .tool-versions.
#   OUT   output folder; raw answers go to $OUT/raw
#   LIST  a TSV whose second column is owner/name, with a header row (first_wave.tsv)
set -euo pipefail
: "${OUT:?output folder}" "${LIST:?first_wave.tsv}"
mkdir -p "$OUT/raw"
tail -n +2 "$LIST" | cut -f2 > "$OUT/batch.txt"
rm -f "$OUT"/raw/fb_*.json "$OUT"/fbchunk_*
split -l 8 -a 2 -d "$OUT/batch.txt" "$OUT/fbchunk_"
for c in "$OUT"/fbchunk_*; do
  q=$(awk -F/ '{ printf "r%d: repository(owner: \"%s\", name: \"%s\") { nameWithOwner languages(first: 6, orderBy: {field: SIZE, direction: DESC}) { totalSize edges { size node { name } } } root: object(expression: \"HEAD:\") { ... on Tree { entries { name type } } } l1: object(expression: \"HEAD:LICENSE\") { ... on Blob { text } } l2: object(expression: \"HEAD:LICENSE.md\") { ... on Blob { text } } l3: object(expression: \"HEAD:LICENSE.txt\") { ... on Blob { text } } mix: object(expression: \"HEAD:mix.exs\") { ... on Blob { text } } tv: object(expression: \"HEAD:.tool-versions\") { ... on Blob { text } } wf: object(expression: \"HEAD:.github/workflows\") { ... on Tree { entries { name } } } }\n", NR, $1, $2 }' "$c")
  f="$OUT/raw/fb_$(basename "$c").json"
  for try in 1 2 3 4; do
    gh api graphql -f query="query { $q }" > "$f" 2>/dev/null || true
    jq -e ".data" "$f" > /dev/null 2>&1 && break
    echo "{}" > "$f"; sleep 5
  done
  sleep 1
done
{
  printf 'repo\telixir_share\tlanguages\tlicence_files\tlicence_head\tmix_elixir\tdatabase_deps\tumbrella\ttool_versions\tcompose_file\tworkflows\n'
  jq -r '
    .data // {} | to_entries[] | select(.value != null) | .value
    | (.languages.totalSize // 0) as $t
    | ([.languages.edges[]? | select(.node.name == "Elixir") | .size] | add // 0) as $e
    | ([.root.entries[]?.name]) as $names
    | (.mix.text // "") as $mix
    | [ .nameWithOwner,
        (if $t > 0 then ($e * 1000 / $t | round / 10) else 0 end),
        ([.languages.edges[]? | "\(.node.name) \((.size * 100 / $t) | round)"] | .[0:4] | join(", ")),
        ([$names[] | select(test("^(licen[cs]e|copying|notice)"; "i"))] | join(",")),
        ((.l1.text // .l2.text // .l3.text // "") | gsub("[\\t\\n\\r ]+"; " ") | .[0:160]),
        (($mix | capture("elixir:\\s*\"(?<v>[^\"]+)\"") | .v) // "-"),
        ([$mix | scan(":(ecto_sql|postgrex|myxql|ecto_sqlite3|exqlite|tds|redix|mongodb_driver|ch|brod|amqp)\\b") | .[0]] | unique | join(",")),
        (if ($names | index("apps")) and ($mix | test("apps_path")) then "yes" else "no" end),
        ((.tv.text // "") | gsub("[\\n\\r]+"; "; ") | gsub("\\t"; " ") | .[0:80]),
        ([$names[] | select(test("^(docker-)?compose.*\\.ya?ml$"; "i"))] | join(",")),
        ([.wf.entries[]?.name] | length) ] | @tsv' "$OUT"/raw/fb_fbchunk_*.json
} > "$OUT/first_batch_checks.tsv"
