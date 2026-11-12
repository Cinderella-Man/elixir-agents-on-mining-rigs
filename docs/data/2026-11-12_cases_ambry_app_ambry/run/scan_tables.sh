#!/usr/bin/env bash
# scan_tables.sh: the public tables of the licence scan and the hold-out check, merged from scan.sh's per-case folders
# (WORK/<id>, given as arguments, in the order the rows should have), on the data-mining machine.
#   licence_tasks.tsv, licence_files.tsv, holdout_tasks.tsv, holdout_hits.tsv: one header, the union of the cases'
#   columns in the order first seen (a column that a case's tool version did not write is "-" for that case), then
#   every case's rows
#   deps.tsv: each locked dependency once per kind, package, version, declared licences and class, with the number of
#   cases whose starting commit locks it; sorted by kind, package and version
# Environment: OUT (the folder to write).
set -euo pipefail
: "${OUT:?}"
[ $# -gt 0 ] || { echo "usage: $0 CASE_FOLDER [...]" >&2; exit 2; }
mkdir -p "$OUT"
files() { local d; for d in "${@:2}"; do printf '%s/%s\n' "$d" "$1"; done; }
merge() { # $1: the table's name in each case folder; the rest: the case folders
  local name=$1
  shift
  mapfile -t list < <(files "$name" "$@")
  awk -F'\t' -v OFS='\t' '
    FNR == 1 {
      nf[FILENAME] = split($0, h, "\t")
      for (i = 1; i <= nf[FILENAME]; i++) {
        col[FILENAME, i] = h[i]
        if (!(h[i] in seen)) {seen[h[i]] = 1; order[++m] = h[i]}
      }
      next
    }
    {r++; for (i = 1; i <= nf[FILENAME]; i++) val[r, col[FILENAME, i]] = $i}
    END {
      line = ""
      for (j = 1; j <= m; j++) line = line (j > 1 ? OFS : "") order[j]
      print line
      for (k = 1; k <= r; k++) {
        line = ""
        for (j = 1; j <= m; j++) line = line (j > 1 ? OFS : "") (((k, order[j]) in val) ? val[k, order[j]] : "-")
        print line
      }
    }' "${list[@]}"
}
merge licence.tasks.tsv "$@" > "$OUT/licence_tasks.tsv"
merge licence.files.tsv "$@" > "$OUT/licence_files.tsv"
merge holdout.tasks.tsv "$@" > "$OUT/holdout_tasks.tsv"
merge holdout.hits.tsv "$@" > "$OUT/holdout_hits.tsv"
mapfile -t deps < <(files deps.tsv "$@")
{
  printf 'kind\tpackage\tversion\tlicences\tclass\ttasks\n'
  awk -F'\t' -v OFS='\t' 'FNR == 1 {next}
    {k = $1 OFS $2 OFS $3 OFS $4 OFS $5; if (!((FILENAME, k) in once)) {once[FILENAME, k] = 1; n[k]++}}
    END {for (k in n) print k, n[k]}' "${deps[@]}" | sort -t $'\t' -k1,1 -k2,2 -k3,3V
} > "$OUT/deps.tsv"
