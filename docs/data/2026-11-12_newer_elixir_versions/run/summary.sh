#!/usr/bin/env bash
# summary.sh: per project, how many of the listed candidates the resolver serves with an image of Elixir 1.18 or
# newer (the dataset's floor), from two outputs of resolve.exs: before (the old table) and after (the new one); and,
# with CLASSES (the screen's classes.tsv), how many of those served after the screen notes another need for (column
# 9, other_lacks: a service, a release file, another toolchain).
# Usage: summary.sh <before.tsv> <after.tsv>. Prints TSV: repo, candidates, served before, served after, served after
# with another need, and the outcomes after that are not served, with their counts.
set -euo pipefail
before=${1:?before.tsv} after=${2:?after.tsv}
printf 'repo\tcandidates\tserved_before\tserved_after\tserved_after_other_need\tnot_served_after\n'
awk -F'\t' '
  function floor_ok(o,   v, p) { if (o !~ /^ok:/) return 0; v = substr(o, 4); split(v, p, /[.\/]/); return (p[1] > 1 || (p[1] == 1 && p[2] >= 18)) }
  FNR == 1 { file++ }
  file == 1 { if (FNR > 1) other[$1 SUBSEP $2] = ($9 != "-"); next }
  file == 2 { if ($2 != "head" && floor_ok($8)) b[$1]++; next }
  $2 == "head" { next }
  { n[$1]++
    if (floor_ok($8)) { a[$1]++; if (other[$1 SUBSEP $2]) o[$1]++ }
    else { k = $1 SUBSEP ($8 ~ /^ok:/ ? "elixir_before_1.18:" substr($8, 4) : $8); miss[k]++ } }
  END {
    for (r in n) {
      rest = ""
      for (k in miss) { split(k, p, SUBSEP); if (p[1] == r) rest = rest (rest ? "; " : "") p[2] " " miss[k] }
      printf "%s\t%d\t%d\t%d\t%d\t%s\n", r, n[r], b[r] + 0, a[r] + 0, o[r] + 0, (rest ? rest : "-")
    }
  }' "${CLASSES:-/dev/null}" "$before" "$after" | sort -f
