#!/usr/bin/env bash
# The pilot's check 2 (check.sh) with one rule added. It counts, from the census's author, flag and path columns, the pull
# requests that pass every rule before the repair rule (code, a _test.exs file, no mix.exs or mix.lock, not by a bot, not
# a revert) and compares that with the screen's candidates plus the pull requests rejected as `repaired_by`. A pull request
# that a later one reverts passes those rules too and is rejected as `reverted_later` (rule 6, before `repaired_by`),
# which the pilot's formula did not count: the pilot's three repositories had none with code and tests. Here the third
# term is added, and the two counts must be equal. Prints one line per repository and exits 1 if one differs.
#   CENSUS  the census folder     OUT  the folder with screen_<slug>.tsv[.gz]
set -euo pipefail
: "${CENSUS:?}"; : "${OUT:?}"
fail=0
for f in "$OUT"/screen_*.tsv "$OUT"/screen_*.tsv.gz; do
  [ -e "$f" ] || continue
  slug=$(basename "$f"); slug=${slug#screen_}; slug=${slug%.gz}; slug=${slug%.tsv}; repo="${slug/__//}"
  [ -f "$CENSUS/prs_$slug.tsv.gz" ] && cen=(gzip -dc "$CENSUS/prs_$slug.tsv.gz") || cen=(cat "$CENSUS/prs_$slug.tsv")
  indep=$("${cen[@]}" | awk -F'\t' 'NR > 1 {
      code = 0; tst = 0; mix = 0; n = split($36, P, ";")
      for (i = 1; i <= n; i++) { p = P[i]; sub(/^apps\/[^\/]+\//, "", p)
        if (p ~ /^(lib|web)\/.*\.(ex|heex|eex|leex)$/) code = 1
        if (p ~ /^test\/.*_test\.exs$/) tst = 1
        if (p == "mix.exs" || p == "mix.lock") mix = 1 }
      if (code && tst && !mix && $4 == 0 && $26 == 0) c++ } END { print c + 0 }')
  mine=$(gzip -dcf "$f" | awk -F'\t' 'NR > 1 && ($4 == "candidate" || $5 == "repaired_by" || $5 == "reverted_later") { c++ } END { print c + 0 }')
  rl=$(gzip -dcf "$f" | awk -F'\t' 'NR > 1 && $5 == "reverted_later" { c++ } END { print c + 0 }')
  if [ "$indep" = "$mine" ]; then echo "ok   $repo: $mine pull requests pass every rule before the repair rule (candidates, repaired and reverted later $rl), counted two ways"
  else echo "FAIL $repo: $indep counted from the census, $mine in the screen (reverted later $rl)"; fail=1; fi
done
exit $fail
