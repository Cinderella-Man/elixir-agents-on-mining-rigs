#!/usr/bin/env bash
# The whole census, in order. Needs gh (logged in), jq, awk, gzip.
#   OUT    the committed folder (prs_*.tsv[.gz], summary.tsv)
#   RAW    raw pages, NOT committed (they hold titles and bodies)
#   WORK   intermediate rows, not committed
#   REPOS  owner/name list (default: the three pilot applications)
#   FETCH  0 reuses the pages already in $RAW (default 1)
set -euo pipefail
: "${OUT:?}"; : "${RAW:?}"; : "${WORK:?}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
if [ "${FETCH:-1}" = 1 ]; then RAW="$RAW" "$here/fetch.sh"; fi
rm -rf "$WORK"
RAW="$RAW" WORK="$WORK" "$here/flatten.sh"
rm -f "$OUT"/prs_*.tsv "$OUT"/prs_*.tsv.gz
WORK="$WORK" OUT="$OUT" "$here/derive.sh"
for f in "$OUT"/prs_*.tsv; do
  if [ "$(du -k "$f" | cut -f1)" -gt 1024 ]; then gzip -n -f "$f"; fi
done
OUT="$OUT" "$here/summarize.sh"
