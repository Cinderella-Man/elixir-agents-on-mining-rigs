#!/usr/bin/env bash
# Fetches the licence file of every git dependency in locks.tsv, at the commit the lock file pins, so that a person
# can read it. A git dependency has no Hex metadata, so check_tasks.sh leaves its licence unread. Each candidate name
# is fetched as a raw file from GitHub and cut at 1 MiB; the first name that exists is kept.
#   WORK  the folder of a check_tasks.sh run (reads locks.tsv; writes gitdeps/ and gitdeps.found.tsv)
set -euo pipefail
: "${WORK:?}"
out=$WORK/gitdeps
mkdir -p "$out"
printf 'package\trepository\tcommit\tfile\tbytes\tsha256\n' > "$WORK/gitdeps.found.tsv"
awk -F'\t' '$1=="git"{print $2"\t"$3}' "$WORK/locks.tsv" | while IFS=$'\t' read -r pkg src; do
  url=${src%%#*}; commit=${src##*#}
  repo=$(echo "$url" | sed -E 's#^https://github.com/##; s#\.git$##')
  d=$out/$pkg-${commit:0:12}; mkdir -p "$d"
  found=""
  for name in LICENSE LICENSE.md LICENSE.txt LICENCE COPYING COPYING.md license license.md; do
    f=$d/$name
    { curl -sSf -A "task-licence-check" "https://raw.githubusercontent.com/$repo/$commit/$name" 2>/dev/null || true; } \
      | head -c 1048576 > "$f.part" || true
    if [ -s "$f.part" ]; then mv "$f.part" "$f"; found=$name; break; else rm -f "$f.part"; fi
  done
  if [ -n "$found" ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pkg" "$repo" "$commit" "$found" "$(wc -c < "$d/$found")" \
      "$(sha256sum "$d/$found" | cut -d' ' -f1)" >> "$WORK/gitdeps.found.tsv"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pkg" "$repo" "$commit" "-" "0" "-" >> "$WORK/gitdeps.found.tsv"
  fi
done
cat "$WORK/gitdeps.found.tsv"
