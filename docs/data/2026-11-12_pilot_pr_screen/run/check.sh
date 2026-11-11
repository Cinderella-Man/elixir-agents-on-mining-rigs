#!/usr/bin/env bash
# Independent checks of the screen against the census, with their own regular expressions (not the scripts' functions).
#   CENSUS  the census folder
#   OUT     the committed folder (screen_<slug>.tsv[.gz], pairs.tsv)
# Prints one line per check and exits 1 if one fails.
set -euo pipefail
: "${CENSUS:?the census folder}"; : "${OUT:?the committed folder}"
fail=0
for f in "$OUT"/screen_*.tsv "$OUT"/screen_*.tsv.gz; do
  [ -e "$f" ] || continue
  slug=$(basename "$f"); slug=${slug#screen_}; slug=${slug%.gz}; slug=${slug%.tsv}; repo="${slug/__//}"
  [ -f "$CENSUS/prs_$slug.tsv.gz" ] && cen=(gzip -dc "$CENSUS/prs_$slug.tsv.gz") || cen=(cat "$CENSUS/prs_$slug.tsv")
  # 1. rows: one per census row, same numbers in the same order
  a=$("${cen[@]}" | awk -F'\t' 'NR > 1 { print $1 }' | md5sum | cut -c1-12)
  b=$(gzip -dcf "$f" | awk -F'\t' 'NR > 1 { print $1 }' | md5sum | cut -c1-12)
  if [ "$a" = "$b" ]; then echo "ok   $repo: same pull-request numbers in the same order as the census"; else echo "FAIL $repo: row numbers differ from the census"; fail=1; fi
  # 2. the pull requests that pass every rule before the repair rule (code, a _test.exs file, no mix.exs or mix.lock, not by
  #    a bot, not a revert), counted straight from the census's author, flag and path columns
  indep=$("${cen[@]}" | awk -F'\t' 'NR > 1 {
      code = 0; tst = 0; mix = 0; n = split($36, P, ";")
      for (i = 1; i <= n; i++) { p = P[i]; sub(/^apps\/[^\/]+\//, "", p)
        if (p ~ /^(lib|web)\/.*\.(ex|heex|eex|leex)$/) code = 1
        if (p ~ /^test\/.*_test\.exs$/) tst = 1
        if (p == "mix.exs" || p == "mix.lock") mix = 1 }
      if (code && tst && !mix && $4 == 0 && $26 == 0) c++ } END { print c + 0 }')
  mine=$(gzip -dcf "$f" | awk -F'\t' 'NR > 1 && ($4 == "candidate" || $5 == "repaired_by") { c++ } END { print c + 0 }')
  if [ "$indep" = "$mine" ]; then echo "ok   $repo: $mine pull requests pass every rule before the repair rule (candidates plus repaired), counted two ways"; else echo "FAIL $repo: $indep counted from the census, $mine in the screen"; fail=1; fi
  # 3. every pair the census saw through a mention within 50 merged and 30 days is in pairs.tsv (unless the later one is a bot)
  miss=$("${cen[@]}" | awk -F'\t' -v repo="$repo" -v PAIRS="$OUT/pairs.tsv" '
      BEGIN { while ((getline l < PAIRS) > 0) { split(l, F, "\t"); if (F[1] == repo) have[F[2] "-" F[3]] = 1 } FS = "\t" }
      NR > 1 { r++; rank[$1] = r; bot[$1] = $4; num[r] = $1; fm[r] = $33 }
      END { for (i = 1; i <= r; i++) { if (fm[i] == "-") continue; n = split(fm[i], L, ";")
              for (k = 1; k <= n; k++) if (rank[L[k]] - i <= 50 && !bot[L[k]] && !((num[i] "-" L[k]) in have)) m++ }
            print m + 0 }')
  if [ "$miss" = 0 ]; then echo "ok   $repo: every census mention pair within 50 merged pull requests is in pairs.tsv"; else echo "FAIL $repo: $miss census mention pairs are missing from pairs.tsv"; fail=1; fi
done
exit $fail
