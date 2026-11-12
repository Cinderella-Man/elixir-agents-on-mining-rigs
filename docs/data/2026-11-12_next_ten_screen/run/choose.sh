#!/usr/bin/env bash
# Step 0b. Choose the ten: the applications of the approved batch, with every reason that leaves one out, then the ten with
# the most merged pull requests. Writes $OUT/choice.tsv (one row per application, decision and reasons) and
# $OUT/ten.txt (the ten, one owner/name per line, most merged pull requests first).
#   LIST     the pool's approved_app_first_batch.tsv (service_deps column)
#   STATE    state.sh's state.tsv (archived, last push, merged pull requests now, Elixir share now)
#   HOLDOUT  factory/config/holdout.json
#   PILOT    space-separated owner/name list of the pilot applications
#   CAP      most merged pull requests an application may have for one job (default 3500)
#   N        how many to take (default 10)
#   OKSVC    drivers the factory can serve (default: ecto_sql postgrex ch redix; ecto_sql is the generic Ecto layer)
#   SINCE    "not pushed since" cut: a last push before this date leaves it out (default 2025-01-01)
#   MINEX    least Elixir share in percent (default 70)
# Reasons, all that apply (the first one is the one counted in the README): pilot, archived, not_pushed_since_2025,
# elixir_under_70, holdout, other_service:<drivers>, over_cap (more than CAP merged pull requests now).
# "over_cap" is the only reason of an application in the later batch.
set -euo pipefail
: "${LIST:?}"; : "${STATE:?}"; : "${HOLDOUT:?}"; : "${OUT:?}"
PILOT="${PILOT:-nerves-hub/nerves_hub_web axelclark/ex338 podlove/radiator}"
CAP="${CAP:-3500}"; N="${N:-10}"; OKSVC="${OKSVC:-ecto_sql postgrex ch redix}"; SINCE="${SINCE:-2025-01-01}"; MINEX="${MINEX:-70}"
mkdir -p "$OUT"
hold=$(jq -r '([.projects[].repository] + [.organisations[] ] + .names) | join(" ")' "$HOLDOUT")
awk -F'\t' -v OFS='\t' -v pilot="$PILOT" -v hold="$hold" -v cap="$CAP" -v okp="$OKSVC" -v since="$SINCE" -v minex="$MINEX" '
  BEGIN { np = split(pilot, P, " "); for (i = 1; i <= np; i++) ispilot[P[i]] = 1
          nh = split(hold, H, " "); for (i = 1; i <= nh; i++) hl[tolower(H[i])] = 1
          no = split(okp, O, " "); for (i = 1; i <= no; i++) ok[O[i]] = 1 }
  FNR == NR { if (FNR > 1) { arch[$1] = $2; pushed[$1] = substr($3, 1, 10); mnow[$1] = $4; exnow[$1] = $5 } ; next }
  FNR == 1 { print "repo", "merged_prs_now", "merged_prs_pool", "elixir_share_now", "elixir_share_pool", "last_push", "archived", "service_deps", "reasons"; next }
  $3 == "application" {
    r = $1; split(r, X, "/"); why = ""
    if (r in ispilot) why = why ";pilot"
    if (arch[r] == "true") why = why ";archived"
    if (pushed[r] < since) why = why ";not_pushed_since_2025"
    if (exnow[r] + 0 < minex) why = why ";elixir_under_" minex
    if (tolower(r) in hl || tolower(X[1]) in hl || tolower(X[2]) in hl) why = why ";holdout"
    n = split($13, D, ","); other = ""
    for (i = 1; i <= n; i++) if (D[i] != "" && !(D[i] in ok)) other = other (other == "" ? "" : ",") D[i]
    if (other != "") why = why ";other_service:" other
    if (mnow[r] + 0 > cap) why = why ";over_cap"
    print r, mnow[r], $9, exnow[r], $10, pushed[r], arch[r], ($13 == "" ? "-" : $13), (why == "" ? "-" : substr(why, 2))
  }' "$STATE" "$LIST" > "$OUT/choice.body"
# rank the ones with no reason by merged pull requests now, the first N are chosen
{ head -1 "$OUT/choice.body" | awk 'BEGIN { FS = OFS = "\t" } { print $0, "decision" }'
  awk -F'\t' -v OFS='\t' 'NR > 1 && $9 == "-"' "$OUT/choice.body" | sort -t$'\t' -k2,2nr | awk -F'\t' -v OFS='\t' -v n="$N" '{ print $0, (NR <= n ? "chosen" : "next_in_line") }'
  awk -F'\t' -v OFS='\t' 'NR > 1 && $9 != "-" { print $0, ($9 == "over_cap" ? "later_batch" : "left_out") }' "$OUT/choice.body" | sort -t$'\t' -k2,2nr
} > "$OUT/choice.tsv"
rm -f "$OUT/choice.body"
awk -F'\t' '$10 == "chosen" { print $1 }' "$OUT/choice.tsv" > "$OUT/ten.txt"
