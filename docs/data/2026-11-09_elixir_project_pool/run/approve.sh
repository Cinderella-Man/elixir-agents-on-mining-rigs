#!/usr/bin/env bash
# The approved first batch: first_wave.tsv joined with first_batch.sh's checks and the hand-written notes.
#   OUT    the folder first_batch.sh wrote first_batch_checks.tsv to
#   DATA   this data folder (first_wave.tsv, first_batch_hand.tsv); writes $DATA/approved_first_batch.tsv
#   DATE   the approval date
set -euo pipefail
: "${OUT:?}" "${DATA:?}" "${DATE:?}"
awk -F'\t' -v OFS='\t' -v date="$DATE" '
  FILENAME ~ /first_batch_hand/ { if (FNR > 1) { kind[$1] = $2; lic[$1] = $3; from[$1] = $4; note[$1] = $5 } next }
  FILENAME ~ /first_batch_checks/ { if (FNR > 1) { share[$1] = $2; el[$1] = $6; db[$1] = $7; tv[$1] = $9 } next }
  FNR == 1 { print "repo", "approved", "kind", "licence", "licence_read_from", "stars", "merged_prs", "elixir_share",
             "mix_elixir", "tool_versions", "service_deps", "note"; next }
  { r = $2; print r, date, kind[r], lic[r], from[r], $3, $4, share[r], el[r], tv[r], db[r], note[r] }
' "$DATA/first_batch_hand.tsv" "$OUT/first_batch_checks.tsv" "$DATA/first_wave.tsv" > "$DATA/approved_first_batch.tsv"
