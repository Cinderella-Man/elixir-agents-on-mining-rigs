#!/usr/bin/env bash
# licence_later.sh: the rules page's section 9 rule for a case older than its project's licence (the owner,
# 2026-11-12: "Yes, count them"), applied to every checked task from files already written: the licence scan's
# tables (SCANS/<id>/licence.tasks.tsv, licence.files.tsv, revisions.tsv), the hold-out check's
# (SCANS/<id>/holdout.tasks.tsv), the record of the licence file (authors.sh: AUTHORS/licence_proof.tsv), the
# project's full clone G, and the task's kind (DEST/<id>/case.json). The scan tool itself is not changed.
# The touched files are the scan's own list (licence.files.tsv): the files the patches touch and the existing test
# files the task names. For each, every commit up to the task's merge commit that touched it is read by author: a
# human author other than HOLDER, or any bot commit, on any touched file leaves the task out.
# A checked task's licence verdict:
#   pass                  the scan passes it
#   pass_later_licence    the scan fails it only because its starting commit holds no licence (root fail:no-licence,
#                         every touched file passing), the project's licence file was added later and is unchanged at
#                         the newest commit read, the starting commit does not hold it, and every touched file was
#                         written only by the licence's holder
#   no_licence_at_commit  as above, but a touched file has another author or a bot commit
#   fail                  any other failure (another notice in a touched file, a file left out of the scan)
# A task is good when it is checked, its licence verdict is pass or pass_later_licence, and its hold-out result is
# pass, or review with every span read as boilerplate (REVIEWS: id in column 1, verdict in column 4, "boilerplate").
# Environment: OUT (all.sh's output folder: rows.tsv), SCANS, AUTHORS, DEST, G, HOLDER (the holder's name as the
# commits give it), REVIEWS (optional).
# Writes OUT/licence_later.tsv (one line per checked task), OUT/licence_later_files.tsv (one line per touched file)
# and OUT/good_final.tsv (newest pull request first); prints the counts. Author names only, no e-mail addresses.
set -euo pipefail
: "${OUT:?}" "${SCANS:?}" "${AUTHORS:?}" "${DEST:?}" "${G:?}" "${HOLDER:?}"
REVIEWS=${REVIEWS:-/dev/null}
proof=$AUTHORS/licence_proof.tsv
added=$(awk -F'\t' 'NR == 2 {print $3}' "$proof")
still=$(awk -F'\t' 'NR == 2 {print $9}' "$proof")
copyright=$(awk -F'\t' 'NR == 2 {print $6}' "$proof")
g() { git --git-dir="$G" "$@"; }
# the last try of each pull request that is not a deferral: id, verdict
last() { awk -F'\t' 'NR > 1 && $1 != "k" {v[$4] = $10} END {for (i in v) print i "\t" v[i]}' "$OUT/rows.tsv"; }
printf 'id\tnumber\tscan_result\troot_licence\tfiles_touched\tfiles_passing\tlicence_at_start\tlicence_added_by\tlicence_unchanged_at_newest\tcopyright_line\thuman_authors\tbot_commits_on_touched_files\tfiles_with_other_human_author\tco_author_trailers\tlicence_verdict\n' > "$OUT/licence_later.tsv"
printf 'id\tpath\tsources\tcommits\thuman_authors\tbot_commits\tco_author_trailers\tother_than_holder\n' > "$OUT/licence_later_files.tsv"
printf 'id\tlicence\tholdout\tkind\tgood\tlicence_verdict\n' > "$OUT/good_final.tsv"
last | awk -F'\t' '$2 == "checked" {print $1}' | sort -t- -k4,4nr | while read -r id; do
  n=${id##*-}
  t=$SCANS/$id/licence.tasks.tsv
  lic=$(awk -F'\t' 'NR == 2 {print $8}' "$t" 2>/dev/null || echo -)
  root=$(awk -F'\t' 'NR == 2 {print $10}' "$t" 2>/dev/null || echo -)
  touched=$(awk -F'\t' 'NR == 2 {print $6}' "$t" 2>/dev/null || echo -)
  passing=$(awk -F'\t' 'NR == 2 {print $7}' "$t" 2>/dev/null || echo -)
  start=$(awk -F'\t' 'NR == 2 {print $3}' "$SCANS/$id/revisions.tsv")
  merge=$(awk -F'\t' 'NR == 2 {print $4}' "$SCANS/$id/revisions.tsv")
  at_start=no; g merge-base --is-ancestor "$added" "$start" && at_start=yes
  humans_all=""; trailers_all=""; bots_all=0; others=0
  while IFS=$'\t' read -r path sources; do
    log=$(g log --format='%H%x09%an%x09%(trailers:key=Co-authored-by,valueonly,separator=;)' "$merge" -- "$path")
    commits=$(printf '%s\n' "$log" | grep -c . || true)
    humans=$(printf '%s\n' "$log" | awk -F'\t' 'NF && $2 !~ /\[bot\]$/ {print $2}' | sort -u | paste -sd';' -)
    bots=$(printf '%s\n' "$log" | awk -F'\t' 'NF && $2 ~ /\[bot\]$/' | wc -l)
    trailers=$(printf '%s\n' "$log" | cut -f3 | tr ';' '\n' | sed -E 's/ *<[^>]*>//; s/^ +//; s/ +$//' | grep . | sort -u | paste -sd';' - || true)
    other=$(printf '%s\n' "$humans" | tr ';' '\n' | grep . | grep -v -x -F "$HOLDER" | paste -sd';' - || true)
    [ -z "$other" ] || others=$((others + 1))
    humans_all="$humans_all;$humans"; trailers_all="$trailers_all;$trailers"; bots_all=$((bots_all + bots))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$sources" "$commits" "${humans:--}" "$bots" "${trailers:--}" "${other:--}" \
      >> "$OUT/licence_later_files.tsv"
  done < <(awk -F'\t' 'NR > 1 {print $2 "\t" $3}' "$SCANS/$id/licence.files.tsv")
  u() { printf '%s\n' "$1" | tr ';' '\n' | grep . | sort -u | paste -sd';' - || true; }
  humans_all=$(u "$humans_all"); trailers_all=$(u "$trailers_all")
  if [ "$lic" = pass ]; then
    v=pass
  elif [ "$lic" = fail ] && [ "$root" = fail:no-licence ] && [ "$touched" = "$passing" ] && [ "$still" = yes ] && [ "$at_start" = no ]; then
    if [ "$others" = 0 ] && [ "$bots_all" = 0 ] && [ "$humans_all" = "$HOLDER" ]; then v=pass_later_licence; else v=no_licence_at_commit; fi
  else
    v=fail
  fi
  hold=$(awk -F'\t' 'NR == 2 {print $NF}' "$SCANS/$id/holdout.tasks.tsv" 2>/dev/null || echo -)
  read_ok=$(awk -F'\t' -v id="$id" '$1 == id {n++; if ($4 != "boilerplate") bad++} END {print (n > 0 && bad == 0) ? "yes" : "no"}' "$REVIEWS")
  kind=$(jq -r '.task_kind // "-"' "$DEST/$id/case.json" 2>/dev/null || echo -)
  good=no
  { [ "$v" = pass ] || [ "$v" = pass_later_licence ]; } && { [ "$hold" = pass ] || { [ "$hold" = review ] && [ "$read_ok" = yes ]; }; } && good=yes
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$n" "$lic" "$root" "$touched" "$passing" \
    "$at_start" "$added" "$still" "$copyright" "${humans_all:--}" "$bots_all" "$others" "${trailers_all:--}" "$v" >> "$OUT/licence_later.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$lic" "$hold" "$kind" "$good" "$v" >> "$OUT/good_final.tsv"
done
echo "good: $(awk -F'\t' 'NR > 1 && $5 == "yes"' "$OUT/good_final.tsv" | wc -l) of $(($(wc -l < "$OUT/good_final.tsv") - 1)) checked"
awk -F'\t' 'NR > 1 && $5 == "yes" {k[$4]++} END {for (x in k) print x "\t" k[x]}' "$OUT/good_final.tsv"
