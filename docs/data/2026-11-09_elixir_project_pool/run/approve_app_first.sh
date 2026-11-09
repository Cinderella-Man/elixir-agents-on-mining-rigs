#!/usr/bin/env bash
# The approved application-first batch: the draft's application and library groups, joined with first_batch.sh's
# checks (run with LIST set to those rows), the mirrors and the hand-written notes.
#   OUT   the folder first_batch.sh wrote first_batch_checks.tsv to
#   DATA  this data folder; writes approved_app_first_batch.tsv
#   DATE  the approval date
set -euo pipefail
: "${OUT:?}" "${DATA:?}" "${DATE:?}"
awk -F'\t' -v OFS='\t' -v date="$DATE" '
  FILENAME ~ /mirrors\.tsv$/ { if (FNR > 1) mirror[$1] = $2; next }
  FILENAME ~ /approved_hand\.tsv$/ { if (FNR > 1) { use[$1] = $2; note[$1] = $3 } next }
  FILENAME ~ /first_batch_checks\.tsv$/ {
    if (FNR > 1) { h = tolower($5); r = "other terms: read the file"
      if (h == "") r = "no licence file at the root"
      else if (h ~ /^content and design copyright/) r = "MIT for code; content and design reserved"
      else if (h ~ /apache license/ || h ~ /licensed under the apache license/) r = "Apache-2.0"
      else if (h ~ /permission is hereby granted, free of charge/ || h ~ /mit license/) r = "MIT"
      else if (h ~ /redistribution and use in source and binary forms/) r = "BSD"
      reads[$1] = r; share[$1] = $2; el[$1] = $6; db[$1] = $7 }
    next }
  FNR == 1 { print "repo", "approved", "group", "use", "mirror", "licence", "licence_file_reads_as", "stars", "merged_prs",
             "elixir_share", "uses", "mix_elixir", "service_deps", "last_pushed", "note"; next }
  $1 == "application" || $1 == "library" {
    r = $2; n = (r in note) ? note[r] : $10
    print r, date, $1, ((r in use) ? use[r] : "yes"), mirror[r], $6, reads[r], $4, $5, share[r], $7, el[r], db[r], $8, n
  }' "$DATA/mirrors.tsv" "$DATA/approved_hand.tsv" "$OUT/first_batch_checks.tsv" "$DATA/draft_app_first_batch.tsv" > "$DATA/approved_app_first_batch.tsv"
