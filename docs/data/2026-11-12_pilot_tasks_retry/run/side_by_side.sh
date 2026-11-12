#!/usr/bin/env bash
# side_by_side.sh: two lines per pull request, the mass run's and the retry's, in the columns of the task tables with
# a first column `run` (mass_run, retry). Pull requests in the order of NUMBERS (space-separated "repository number"
# pairs, one per line: the repository's short name and the number). The empty last field of the mass run's lines
# is dropped.
#   side_by_side.sh NUMBERS RETRY_TSV MASS_TSV... > tasks.tsv
set -euo pipefail
numbers=${1:?NUMBERS}
retry=${2:?RETRY_TSV}
shift 2
head -n 1 "$retry" | sed 's/^/run\t/'
while read -r repo number; do
  for f in "$@"; do
    awk -F'\t' -v r="$repo" -v n="$number" 'FNR > 1 && $1 ~ ("/" r "$") && $2 == n {line = $0; sub(/\t$/, "", line); print "mass_run\t" line}' "$f"
  done
  awk -F'\t' -v r="$repo" -v n="$number" 'FNR > 1 && $1 ~ ("/" r "$") && $2 == n {print "retry\t" $0}' "$retry"
done < "$numbers"
