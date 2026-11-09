#!/usr/bin/env bash
# The final table: every repository with its tier, from build.sh's projects_all.tsv and prs.sh's
# prs.tsv and licence_heads.tsv.
#   OUT  the folder the other scripts wrote to; writes $OUT/licence_read.tsv and $OUT/projects.tsv
# Licence class: GitHub's SPDX id first; else the Hex package's licences; else the licence file's first lines.
# Tiers:
#   A  a permissive licence, a code base, not archived, created before 2024,
#      and 1,000 or more stars or a Hex package with 10,000,000 or more downloads
#   B  the same with 300 or more stars or 1,000,000 or more downloads, created before 2025
#   C  every other permissive candidate (fewer stars, newer, archived, or learning material and templates)
#   check:*  the licence needs a read by hand;  out:*  not usable (hold-out, copyleft)
set -euo pipefail
: "${OUT:?output folder}"

awk -F'\t' 'NR > 1 { h = tolower($2); r = "other"
  if (h == "") r = "no_file"
  else if (h ~ /gnu affero/) r = "AGPL"
  else if (h ~ /gnu lesser/) r = "LGPL"
  else if (h ~ /gnu general public/) r = "GPL"
  else if (h ~ /mozilla public license/) r = "MPL-2.0"
  else if (h ~ /apache license/ && h ~ /version 2\.0/) r = "Apache-2.0"
  else if (h ~ /permission is hereby granted, free of charge/ || h ~ /mit license/) r = "MIT"
  else if (h ~ /redistribution and use in source and binary forms/) r = "BSD"
  else if (h ~ /permission to use, copy, modify, and\/or distribute/ || h ~ /isc license/) r = "ISC"
  else if (h ~ /free and unencumbered software/) r = "Unlicense"
  print $1 "\t" r }' "$OUT/licence_heads.tsv" > "$OUT/licence_read.tsv"

awk -F'\t' -v OFS='\t' '
  FILENAME ~ /licence_read/ { rd[$1] = $2; next }
  FILENAME ~ /prs\.tsv/ { if (FNR > 1) { pr[$1] = $2; td[$1] = $3; mx[$1] = $4 } next }
  FNR == 1 { print "tier", "repo", "stars", "merged_prs", "test_dir", "mix_exs", "licence_github", "licence_class",
             "kind_guess", "holdout", "archived", "created", "pushed", "forks", "size_kb", "hex_package",
             "hex_downloads", "description"; next }
  {
    class = $5
    if ((class == "none" || class == "check") && ($1 in rd)) {
      r = rd[$1]
      if (r == "MIT" || r == "Apache-2.0" || r == "BSD" || r == "ISC" || r == "Unlicense") class = "permissive_per_file"
      else if (r == "AGPL" || r == "GPL" || r == "LGPL" || r == "MPL-2.0") class = "copyleft"
      else if (r == "no_file") class = "none"
      else class = "check"
    }
    text = tolower($1 " " $16)
    kind = (text ~ /awesome|curated list|koans|exercis|curriculum|(^|[^a-z])courses?([^a-z]|$)|tutorial|(^|[^a-z])books?([^a-z]|$)|(^|[^a-z])notes([^a-z]|$)|learn(ing)? elixir|learning exercises|lifelong|workshop|(^|[^a-z])katas?([^a-z]|$)|cheat ?sheet|interview|(^|[^a-z])examples?([^a-z]|$)|(^|[^a-z])samples?([^a-z]|$)|(^|[^a-z])demos?([^a-z]|$)|boilerplate|starter|skeleton|playground|advent.of.code|dotfiles|code.smells|30-days|elixir ?school|(^|[^a-z])lessons?([^a-z]|$)/) ? "learning_or_template" : "code"
    big = ($2 >= 1000 || $13 >= 10000000); mid = ($2 >= 300 || $13 >= 1000000)
    if ($6 != "-") tier = "out:holdout"
    else if (class == "copyleft" || class == "weak_copyleft") tier = "out:copyleft"
    else if (class == "none") tier = "check:no_licence_file"
    else if (class == "check") tier = "check:licence"
    else if (kind == "code" && $7 != "true" && $9 < "2024-01-01" && big) tier = "A"
    else if (kind == "code" && $7 != "true" && $9 < "2025-01-01" && mid) tier = "B"
    else tier = "C"
    print tier, $1, $2, (($1 in pr) ? pr[$1] : "-"), (($1 in td) ? td[$1] : "-"), (($1 in mx) ? mx[$1] : "-"),
          $4, class, kind, $6, $7, $9, $10, $3, $11, $12, $13, $16
  }' "$OUT/licence_read.tsv" "$OUT/prs.tsv" "$OUT/projects_all.tsv" > "$OUT/projects.tsv"
