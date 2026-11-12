#!/usr/bin/env bash
# checked.sh: one line per checked case of this job (each task folder in DEST), from the engine's result of its last
# checked try, its case.json, the two scans and the table of authors, with whether the case counts:
#   - the gate: hidden tests that fail first and pass after, existing test files kept and left out (with the reasons),
#     the partial fix, the second round;
#   - the licence: the scan's result, its root licence (a licence file, a README statement, or none at the case's
#     starting commit), files touched and passing, and whether the licence holder alone wrote every touched file;
#   - the route by which the licence rule holds (rules, section 9): `licence-file`, `readme-statement`, or
#     `licence-stated-later` (the scan fails only for no licence at the starting commit, every touched file passes the
#     per-file check, and the holder alone wrote every touched file), else `fail`;
#   - the hold-out check's result; counts = yes when the route holds and the hold-out check passes.
#   checked.sh > checked.tsv
# Environment: OUT (all.sh's output folder: <id>/<try>/result.json), DEST (the checked task folders), SCANS (the scans'
# folder: <id>/licence.tasks.tsv, <id>/holdout.tasks.tsv), AUTHORS (licence_authors.tsv: number, file, ..., holder_only
# in column 6).
set -euo pipefail
: "${OUT:?}" "${DEST:?}" "${SCANS:?}" "${AUTHORS:?}"
col() { # $1 table, $2 column name: the value in its first data row, "-" when missing
  awk -F'\t' -v k="$2" 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == k) c = i; next} NR == 2 {v = (c ? $c : ""); print (v == "" ? "-" : v); exit}' "$1" 2>/dev/null || echo -
}
printf 'task\tkind\ttry\thidden_failing_first\thidden_passing_after\texisting_files_kept\texisting_files_left_out\tleft_out_reasons\tpartial_fix\tsecond_round_same\tlicence_result\troot_licence\tfiles_touched\tfiles_passing\tholder_wrote_all\tlicence_route\tholdout_result\tcounts\n'
for d in $(ls -d "$DEST"/*/ | sort -t- -k3 -nr); do
  id=$(basename "$d")
  n=${id##*-}
  try=-; r=
  for t in 2 1; do
    f=$OUT/$id/$t/result.json
    if [ -f "$f" ] && [ "$(jq -r .verdict "$f")" = checked ]; then try=$t; r=$f; break; fi
  done
  [ -n "$r" ] || { printf '%s\tno checked try\n' "$id"; continue; }
  gate=$(jq -r '[.hidden_failing_first, .hidden_passing_after, .preservation_files, (.preservation_left_out | length),
    ([.preservation_left_out[]? | (.reason // tostring)] | unique | join(",") | if . == "" then "-" else . end),
    (if .partial_control.present then "present" else (.partial_control.reason // "absent") end),
    (if .second_round.same then "yes" else "no" end)] | map(tostring) | join("\t")' "$r")
  l=$SCANS/$id/licence.tasks.tsv
  result=$(col "$l" licence_result) root=$(col "$l" root_licence) touched=$(col "$l" files_touched) passing=$(col "$l" files_passing)
  failing=$(col "$l" failing)
  holder=$(awk -F'\t' -v n="$n" 'NR > 1 && $1 == n {c++; if ($6 != "yes") o++} END {print (c && !o) ? "yes" : (c ? "no" : "-")}' "$AUTHORS")
  route=fail
  if [ "$result" = pass ]; then
    route=${root#ok:}
  elif [ "$root" = fail:no-licence ] && [ "$touched" = "$passing" ] && [ "$holder" = yes ] &&
    [ "$(printf '%s' "$failing" | sed -E 's/root licence not [^(]*\(fail:no-licence\); *//')" = "" ]; then
    route=licence-stated-later
  fi
  hold=$(col "$SCANS/$id/holdout.tasks.tsv" holdout_result)
  counts=no
  [ "$route" != fail ] && [ "$hold" = pass ] && counts=yes
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(jq -r .task_kind "$d/case.json")" "$try" "$gate" \
    "$result" "$root" "$touched" "$passing" "$holder" "$route" "$hold	$counts"
done
