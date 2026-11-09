#!/usr/bin/env bash
# Applications among the Elixir repositories with 10 to 99 stars and an MIT, Apache-2.0 or BSD licence by GitHub's
# reading. Metadata, mix.exs and folder names only; nothing is cloned and nothing runs.
#   OUT    work folder (raw answers in $OUT/raw; needs hex_by_repo.json from build.sh)
#   DATA   this data folder (reads projects.tsv for the hold-out organisations; writes applications_below_100.tsv
#          and below_100_counts.tsv)
#   STAGE  gather, classify or table (default: all three)
set -euo pipefail
: "${OUT:?}" "${DATA:?}"
stage="${STAGE:-all}"
mkdir -p "$OUT/raw"

if [ "$stage" = gather ] || [ "$stage" = all ]; then
  rm -f "$OUT"/raw/low_*.json
  for range in '50..99' '30..49' '20..29' '15..19' '10..14'; do
    for lic in mit apache-2.0 bsd-3-clause bsd-2-clause; do
      page=1
      while :; do
        f="$OUT/raw/low_${range//./_}_${lic}_$page.json"
        gh api -X GET search/repositories -f q="language:Elixir stars:$range license:$lic" -f sort=stars -f order=desc \
          -f per_page=100 -f page="$page" > "$f"
        sleep 2.2
        [ "$(jq '.items | length' "$f")" -lt 100 ] && break
        page=$((page + 1))
      done
    done
  done
  jq -r '.items[] | .full_name' "$OUT"/raw/low_*.json | sort -u > "$OUT/low.txt"
fi

if [ "$stage" = classify ] || [ "$stage" = all ]; then
  # One query per 10 repositories, JOBS queries at a time; a chunk that already has an answer is skipped.
  ls "$OUT"/lcchunk_* > /dev/null 2>&1 || split -l 10 -a 3 -d "$OUT/low.txt" "$OUT/lcchunk_"
  fetch_chunk() {
    c="$1"; f="$OUT/raw/lc_$(basename "$c").json"
    jq -e ".data" "$f" > /dev/null 2>&1 && return 0
    q=$(awk -F/ '{ printf "r%d: repository(owner: \"%s\", name: \"%s\") { nameWithOwner stargazerCount isArchived pushedAt description licenseInfo { spdxId } pullRequests(states: MERGED) { totalCount } tests: object(expression: \"HEAD:test\") { __typename } mix: object(expression: \"HEAD:mix.exs\") { ... on Blob { text } } m1: object(expression: \"HEAD:elixir/mix.exs\") { ... on Blob { text } } m2: object(expression: \"HEAD:server/mix.exs\") { ... on Blob { text } } m3: object(expression: \"HEAD:backend/mix.exs\") { ... on Blob { text } } lib: object(expression: \"HEAD:lib\") { ... on Tree { entries { name } } } apps: object(expression: \"HEAD:apps\") { ... on Tree { entries { name } } } mig: object(expression: \"HEAD:priv/repo/migrations\") { __typename } }\n", NR, $1, $2 }' "$c")
    for try in 1 2 3 4; do
      gh api graphql -f query="query { $q }" > "$f" 2>/dev/null || true
      jq -e ".data" "$f" > /dev/null 2>&1 && return 0
      echo "{}" > "$f"; sleep 5
    done
  }
  export -f fetch_chunk; export OUT
  ls "$OUT"/lcchunk_* | xargs -P "${JOBS:-4}" -I{} bash -c 'fetch_chunk "$1"' _ {}
fi

if [ "$stage" = table ] || [ "$stage" = all ]; then
  orgs=$(tail -n +2 "$DATA/projects.tsv" | awk -F'\t' '$10 != "-" {split($2, p, "/"); print tolower(p[1])}' | sort -u | jq -R . | jq -sc .)
  jq -r --slurpfile hex "$OUT/hex_by_repo.json" --argjson orgs "$orgs" '
    .data // {} | to_entries[] | select(.value != null) | .value
    | ((.mix.text // "") + "\n" + (.m1.text // "") + "\n" + (.m2.text // "") + "\n" + (.m3.text // "")) as $mix
    | ([.lib.entries[]?.name] + [.apps.entries[]?.name]) as $dirs
    | ((.nameWithOwner + " " + (.description // "")) | ascii_downcase) as $text
    | (.nameWithOwner | ascii_downcase) as $k
    | def has($re): ($mix | test($re));
      ([ (if has("\\{:phoenix,") then "phoenix" else empty end),
         (if has("\\{:phoenix_live_view,") then "live_view" else empty end),
         (if has("\\{:ecto_sql,|\\{:ecto,") then "ecto" else empty end),
         (if has("\\{:ash,|\\{:ash_[a-z_]+,") then "ash" else empty end),
         (if has("\\{:nerves,") then "nerves" else empty end),
         (if has("\\{:nx,|\\{:bumblebee,|\\{:axon,") then "nx" else empty end),
         (if has("\\{:oban,") then "oban" else empty end),
         (if has("\\{:absinthe,") then "absinthe" else empty end),
         (if has("\\{:broadway") then "broadway" else empty end) ]) as $uses
    | ($dirs | any(test("(_web|^web|^api)$"))) as $web
    | (.mig != null) as $mig
    | (has("package:|defp? package\\b") or ($hex[0][$k] != null)) as $lib
    | (if ($text | test("awesome|curated list|koans|exercis|curriculum|(^|[^a-z])courses?([^a-z]|$)|tutorial|(^|[^a-z])books?([^a-z]|$)|(^|[^a-z])notes([^a-z]|$)|learn(ing)? elixir|learning exercises|lifelong|workshop|(^|[^a-z])katas?([^a-z]|$)|cheat ?sheet|interview|(^|[^a-z])examples?([^a-z]|$)|(^|[^a-z])samples?([^a-z]|$)|(^|[^a-z])demos?([^a-z]|$)|boilerplate|starter|skeleton|playground|advent.of.code|dotfiles|code.smells|30-days|elixir ?school|(^|[^a-z])lessons?([^a-z]|$)")) then "learning_or_template"
       elif $lib then "library_framework_or_tool"
       elif ($uses | index("nerves")) then "application_nerves"
       elif (($uses | index("phoenix")) and ($web or $mig)) then "application_web"
       elif (($uses | length) > 0) then "application_other"
       elif (($mix | length) < 5) then "unclear_no_root_mix"
       else "unpublished_tool_or_library" end) as $kind
    | [ .nameWithOwner, $kind, .stargazerCount, .pullRequests.totalCount, (.licenseInfo.spdxId // "none"),
        ($uses | join(",")), (if $web then "yes" else "no" end), (if $mig then "yes" else "no" end),
        (if .tests then "yes" else "no" end), .isArchived, .pushedAt[0:10],
        (if ((.nameWithOwner | split("/")[0] | ascii_downcase) | IN($orgs[])) then "same_org" else "-" end),
        ((.description // "") | gsub("[\\t\\n\\r]"; " ") | .[0:120]) ] | @tsv
  ' "$OUT"/raw/lc_lcchunk_*.json | sort -t$'\t' -k4,4nr > "$OUT/low_all.tsv"
  { printf 'usage_kind\trepositories\tmerged_prs\n'
    awk -F'\t' '{n[$2]++; p[$2] += $4} END {for (k in n) print k "\t" n[k] "\t" p[k]}' "$OUT/low_all.tsv" | sort -t$'\t' -k2,2nr
  } > "$DATA/below_100_counts.tsv"
  { printf 'repo\tusage_kind\tstars\tmerged_prs\tlicence_github\tuses\tweb_folder\tmigrations\ttest_dir\tarchived\tpushed\tholdout\tdescription\n'
    awk -F'\t' '$2 ~ /^application/' "$OUT/low_all.tsv"
  } > "$DATA/applications_below_100.tsv"
fi
