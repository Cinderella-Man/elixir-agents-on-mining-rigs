#!/usr/bin/env bash
# The application-first draft batch: applications with real history first, a short list of libraries second.
#   DATA  this data folder; reads projects.tsv, usage_kinds.tsv, applications_below_100.tsv, mirrors.tsv,
#         draft_hand.tsv, library_share.tsv; writes draft_app_first_batch.tsv
# Groups:
#   application        100 or more merged pull requests, pushed since 2024
#   application_older  100 or more merged pull requests, last pushed before 2024 (older Phoenix idioms)
#   application_small  30 to 99 merged pull requests, pushed since 2024 (ground for planted bugs)
#   library            the library share (library_share.tsv)
set -euo pipefail
: "${DATA:?}"
awk -F'\t' -v OFS='\t' '
  function group(prs, pushed) {
    if (prs >= 100 && pushed >= "2024-01-01") return "application"
    if (prs >= 100) return "application_older"
    if (prs >= 30 && pushed >= "2024-01-01") return "application_small"
    return ""
  }
  FILENAME ~ /mirrors\.tsv$/ { if (FNR > 1) forked[$1] = 1; next }
  FILENAME ~ /draft_hand\.tsv$/ { if (FNR > 1) { dec[$1] = $2; hlic[$1] = $3; hnote[$1] = $4 } next }
  FILENAME ~ /library_share\.tsv$/ { if (FNR > 1) { libs[$1] = $2; order[++nl] = $1 } next }
  FILENAME ~ /projects\.tsv$/ { if (FNR > 1) { tier[$2] = $1; lic[$2] = $7; pushed[$2] = $13; stars[$2] = $3; prs[$2] = $4 } next }
  FILENAME ~ /usage_kinds\.tsv$/ {
    if (FNR == 1) { print "group", "repo", "found", "stars", "merged_prs", "licence", "uses", "last_pushed", "already_forked", "note"; next }
    r = $1; usable = ($2 == "A" || $2 == "B" || $2 == "C")
    if ($3 !~ /^application/ || dec[r] == "exclude") next
    if (!usable && dec[r] != "include") next
    g = group($10 + 0, pushed[r]); if (g == "") next
    print g, r, (usable ? "100 stars or more" : "100 stars or more, licence read by hand"), $9, $10, (hlic[r] != "" ? hlic[r] : lic[r]), $4, pushed[r], ((r in forked) ? "yes" : "no"), hnote[r]
    next
  }
  FILENAME ~ /applications_below_100\.tsv$/ {
    if (FNR == 1 || $12 != "-" || dec[$1] == "exclude") next
    g = group($4 + 0, $11); if (g == "") next
    print g, $1, "below 100 stars", $3, $4, $5, $6, $11, (($1 in forked) ? "yes" : "no"), hnote[$1]
    next
  }
  END { for (i = 1; i <= nl; i++) { r = order[i]; print "library", r, "100 stars or more", stars[r], prs[r], lic[r], "", pushed[r], ((r in forked) ? "yes" : "no"), libs[r] } }
' "$DATA/mirrors.tsv" "$DATA/draft_hand.tsv" "$DATA/library_share.tsv" "$DATA/projects.tsv" "$DATA/usage_kinds.tsv" "$DATA/applications_below_100.tsv" |
  awk -F'\t' 'NR == 1 { print; next } { print | "sort -t\"\t\" -k1,1 -k5,5nr" }' > "$DATA/draft_app_first_batch.tsv"
