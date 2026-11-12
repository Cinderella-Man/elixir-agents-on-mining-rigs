#!/usr/bin/env bash
# pairs_table.sh: one line per pair proved by prove.sh, with what it serves in resolve.exs's output for the new table:
# the candidates whose image is that pair's line, by project, and the projects whose head it serves.
# Usage: pairs_table.sh <resolve_after.tsv> <proofs.tsv>... Prints TSV, newest pair first.
set -euo pipefail
after=${1:?resolve_after.tsv}
shift
printf 'elixir\totp\timage\tpull\tstarts\tversions\thex\tcandidates\tby_project\theads\tdetail\n'
awk -F'\t' '
  FNR == 1 { file++ }
  file == 1 {
    if ($8 !~ /^ok:/) next
    p = substr($8, 4)
    if ($2 == "head") h[p] = h[p] (h[p] ? ", " : "") $1
    else { n[p]++; c[p SUBSEP $1]++ }
    next
  }
  {
    p = $1 "/" $2
    if (p in seen) next
    seen[p] = 1
    by = ""
    for (k in c) { split(k, q, SUBSEP); if (q[1] == p) by = by (by ? ", " : "") q[2] " " c[k] }
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7, n[p] + 0, (by ? by : "-"), (h[p] ? h[p] : "-"), $8
  }' "$after" "$@" | sort -t "$(printf '\t')" -k1,1Vr -k2,2Vr
