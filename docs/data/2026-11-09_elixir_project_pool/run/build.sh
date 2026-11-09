#!/usr/bin/env bash
# One row per repository from gather.sh's raw pages, with its licence class and hold-out mark.
#   OUT  the folder gather.sh wrote to; writes $OUT/projects_all.tsv
set -euo pipefail
: "${OUT:?output folder}"

# Hex packages by the GitHub repository their links name: the most downloaded package and the package count.
jq -s '
  [ .[][] | . as $p
    | ([$p.meta.links // {} | to_entries[] | .value | strings
        | select(test("github\\.com/[^/]+/[^/#?]+"; "i"))
        | capture("github\\.com/(?<o>[^/]+)/(?<r>[^/#?]+)"; "i")
        | (.o + "/" + (.r | sub("\\.git$"; ""))) | ascii_downcase] | unique | .[0]) as $repo
    | select($repo != null)
    | {repo: $repo, name: $p.name, downloads: ($p.downloads.all // 0), licenses: ($p.meta.licenses // [])} ]
  | group_by(.repo)
  | map({key: .[0].repo, value: {packages: length, top: (max_by(.downloads))}})
  | from_entries' "$OUT"/raw/hex_*.json > "$OUT/hex_by_repo.json"

jq -rs --slurpfile hex "$OUT/hex_by_repo.json" '
  def permissive: ["MIT","Apache-2.0","BSD-2-Clause","BSD-3-Clause","ISC","0BSD","Unlicense","CC0-1.0","Zlib","BSL-1.0","MIT-0"];
  def weak: ["MPL-2.0","LGPL-2.1","LGPL-3.0","EPL-1.0","EPL-2.0"];
  def strong: ["GPL-2.0","GPL-3.0","AGPL-3.0","EUPL-1.1","EUPL-1.2","OSL-3.0","CC-BY-SA-4.0","CC-BY-NC-SA-4.0","CC-BY-NC-4.0"];
  def hexok: ["MIT","Apache-2.0","Apache 2.0","Apache 2","BSD-2-Clause","BSD-3-Clause","ISC","0BSD","Unlicense","CC0-1.0","BSD"];
  def bench: ["absinthe-graphql/absinthe","beaconcms/beacon","ash-project/ash","fly-apps/live_beats","kieraneglin/pinchflat",
              "livebook-dev/livebook","mirego/accent","operately/operately","plausible/analytics","ueberauth/guardian",
              "whitfin/cachex","wintermeyer/vutuv"];
  (bench | map(split("/")[0]) | unique) as $orgs
  | (["repo","stars","forks","licence_github","licence_class","holdout","archived","fork","created","pushed","size_kb",
      "hex_package","hex_downloads","hex_packages","hex_licences","description"] | @tsv),
    ( [.[].items[]] | unique_by(.full_name) | sort_by(-.stargazers_count)[]
      | (.full_name | ascii_downcase) as $k
      | ($hex[0][$k] // null) as $h
      | (.license.spdx_id // "none") as $l
      | (if ($l | IN(permissive[])) then "permissive"
         elif ($l | IN(weak[])) then "weak_copyleft"
         elif ($l | IN(strong[])) then "copyleft"
         elif ($h != null and ($h.top.licenses | length) > 0 and ($h.top.licenses | all(IN(hexok[])))) then "permissive_per_hex"
         elif $l == "none" then "none"
         else "check" end) as $class
      | (if ($k | IN(bench[])) then "bench" elif (($k | split("/")[0]) | IN($orgs[])) then "same_org" else "-" end) as $hold
      | [.full_name, .stargazers_count, .forks_count, $l, $class, $hold, .archived, .fork,
         .created_at[0:10], .pushed_at[0:10], .size,
         ($h.top.name // "-"), ($h.top.downloads // 0), ($h.packages // 0), (($h.top.licenses // []) | join(",")),
         ((.description // "") | gsub("[\\t\\n\\r]"; " ") | .[0:140])] | @tsv )
' "$OUT"/raw/gh_*.json > "$OUT/projects_all.tsv"
