#!/usr/bin/env bash
# licence_proof.sh: for each candidate, what the project stated about its licence at the candidate's starting commit,
# and who wrote the files the candidate changes. For the open question of a licence stated after the commit (the
# project's README states MIT from README_COMMIT on, its licence file exists from LICENCE_COMMIT on).
#   licence_proof.sh candidates > licence_proof.tsv
#   licence_proof.sh files      > licence_authors.tsv
# Environment: CLONE (a bare clone of the project), KINDS (kinds.tsv: number, merged, start, merge in columns 1 to 4),
# README_COMMIT and README_SENTENCE (the commit that first states the licence in README.md, and that sentence),
# LICENCE_COMMIT (the commit that adds the licence file LICENCE_FILE, default LICENSE), HOLDER (an extended regular
# expression for the licence holder's author names; matched against the author name of each commit), NUMBERS
# (optional: a file of the numbers to list, one per line; default every row of KINDS).
# candidates prints: number, merged, start, start_date (the commit's date), readme_states_licence (README.md at the
#   start holds README_SENTENCE), licence_file_at_start, readme_proof (file@commit:line, date), licence_file_proof
#   (file@commit, date, its copyright line), files_changed, files_holder_only, files_other_authors (file: names).
# files prints: number, file, change (A/M/D), commits (that touched the file up to the merge commit), authors (name
#   and number of commits, most first), holder_only.
set -euo pipefail
export LC_ALL=C
: "${CLONE:?}" "${KINDS:?}" "${README_COMMIT:?}" "${README_SENTENCE:?}" "${LICENCE_COMMIT:?}" "${HOLDER:?}"
LICENCE_FILE=${LICENCE_FILE:-LICENSE}
g() { git --git-dir="$CLONE" "$@"; }
rows() { # the rows of KINDS with a merge commit, only the numbers of NUMBERS when it is set
  awk -F'\t' -v list="${NUMBERS:-}" 'BEGIN {if (list != "") while ((getline n < list) > 0) want[n] = 1}
    NR > 1 && $4 != "-" && (list == "" || ($1 in want))' "$KINDS"
}
what=${1:?candidates|files}
readme_line=$(g show "$README_COMMIT:README.md" | grep -nF "$README_SENTENCE" | head -n 1 | cut -d: -f1)
readme_proof="README.md@$(g rev-parse --short=12 "$README_COMMIT"):$readme_line, $(g log -1 --format=%cs "$README_COMMIT")"
copyright=$(g show "$LICENCE_COMMIT:$LICENCE_FILE" | grep -m1 -i '^copyright' | sed -E 's/ *<[^>]*>//')
licence_proof="$LICENCE_FILE@$(g rev-parse --short=12 "$LICENCE_COMMIT"), $(g log -1 --format=%cs "$LICENCE_COMMIT"), $copyright"
authors() { # $1 merge, $2 file: "name (n); ..." most commits first
  g log --format=%an "$1" -- "$2" | sort | uniq -c | sort -k1,1nr -k2 | awk '{n = $1; $1 = ""; sub(/^ /, ""); printf "%s%s (%d)", (NR > 1 ? "; " : ""), $0, n}'
}
others() { # $1 merge, $2 file: the author names that do not match HOLDER, one per line
  g log --format=%an "$1" -- "$2" | sort -u | grep -vE "$HOLDER" || true
}
case $what in
candidates)
  printf 'number\tmerged\tstart\tstart_date\treadme_states_licence\tlicence_file_at_start\treadme_proof\tlicence_file_proof\tfiles_changed\tfiles_holder_only\tfiles_other_authors\n'
  rows | awk -F'\t' '{print $1 "\t" $2 "\t" $3 "\t" $4}' |
  while IFS=$'\t' read -r number merged start merge; do
    rs=no; g show "$start:README.md" 2>/dev/null | grep -qF "$README_SENTENCE" && rs=yes
    lf=no; g cat-file -e "$start:$LICENCE_FILE" 2>/dev/null && lf=yes
    n=0; h=0; o=""
    while IFS=$'\t' read -r _st f; do
      n=$((n + 1))
      x=$(others "$merge" "$f" | tr '\n' ',' | sed 's/,$//')
      if [ -z "$x" ]; then h=$((h + 1)); else o="$o${o:+; }$f: $x"; fi
    done < <(g diff --no-renames --name-status "$start" "$merge")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "${merged:0:10}" "$start" \
      "$(g log -1 --format=%cs "$start")" "$rs" "$lf" "$readme_proof" "$licence_proof" "$n" "$h" "${o:--}"
  done
  ;;
files)
  printf 'number\tfile\tchange\tcommits\tauthors\tholder_only\n'
  rows | awk -F'\t' '{print $1 "\t" $3 "\t" $4}' |
  while IFS=$'\t' read -r number start merge; do
    while IFS=$'\t' read -r st f; do
      c=$(g log --format=%h "$merge" -- "$f" | wc -l)
      x=$(others "$merge" "$f")
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$number" "$f" "$st" "$c" "$(authors "$merge" "$f")" "$([ -z "$x" ] && echo yes || echo no)"
    done < <(g diff --no-renames --name-status "$start" "$merge")
  done
  ;;
*) echo "unknown table $what"; exit 2 ;;
esac
