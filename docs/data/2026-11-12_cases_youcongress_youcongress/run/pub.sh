#!/usr/bin/env bash
# pub.sh: the data folder's tables, on the data-mining machine (pub.sh of docs/data/2026-11-12_cases_hexpm_hexpm, for
# one run):
#   - tasks_youcongress.tsv: one line per try (OUT/tables/tasks_own.tsv);
#   - counts.tsv: pull requests per verdict, step and reason, each counted by its last try;
#   - scans.tsv, licence_files.tsv, holdout_tasks.tsv, deps_flagged.tsv: from the scans of every checked task in
#     SCANS (scans.sh's folders);
#   - licence_root.tsv: per task, the root licence's result and its proof (file, commit, line, sentence) and the
#     sha256 of that file, from the scan of the task's starting commit;
#   - checked.tsv: per checked task, from the engine's result of its checked try: the hidden tests that fail first
#     and pass after, the existing test files kept and left out (with the reason), whether a partial fix is present,
#     and whether the second round agreed.
# Environment: OUT (all.sh's output folder), SCANS, DEST (where to write).
set -euo pipefail
: "${OUT:?}" "${SCANS:?}" "${DEST:?}"
mkdir -p "$DEST"
T=$DEST/tasks_youcongress.tsv
cp "$OUT/tables/tasks_own.tsv" "$T"
# counts: the last try of each pull request (column 3 the id, 8 verdict, 9 step, 10 reason); "not run" rows too
awk -F'\t' 'NR > 1 {last[$3] = $8 "\t" $9 "\t" $10} END {for (i in last) print last[i]}' "$T" | sort | uniq -c | sort -rn \
  | awk 'BEGIN {print "pull_requests\tverdict\tdropped_at\treason"} {c = $1; sub(/^ *[0-9]+ /, ""); print c "\t" $0}' \
  > "$DEST/counts.tsv"
ids=$(ls "$SCANS" | sed -n 's/\.done$//p' | sort)
if [ -n "$ids" ]; then
  head1() { head -1 "$SCANS/$(printf '%s\n' "$ids" | head -1)/$1"; }
  cp "$SCANS/scans.tsv" "$DEST/scans.tsv"
  { head1 licence.files.tsv; for i in $ids; do tail -n +2 "$SCANS/$i/licence.files.tsv"; done; } > "$DEST/licence_files.tsv"
  { head1 holdout.tasks.tsv; for i in $ids; do tail -n +2 "$SCANS/$i/holdout.tasks.tsv"; done; } > "$DEST/holdout_tasks.tsv"
  {
    printf 'kind\tpackage\tversion\tlicences\tclass\ttasks\n'
    for i in $ids; do tail -n +2 "$SCANS/$i/deps.tsv"; done \
      | awk -F'\t' '$5 != "allowed" {k = $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5; n[k]++} END {for (k in n) print k "\t" n[k]}' | sort
  } > "$DEST/deps_flagged.tsv"
  {
    printf 'task\tstart\troot_licence\tlicence_file\tlicence_file_sha256\tfamilies\tholders\tline\tstatement\tmentions\n'
    for i in $ids; do
      start=$(awk -F'\t' 'NR == 2 {print $2}' "$SCANS/$i/licence.tasks.tsv")
      jq -r --arg t "$i" --arg s "$start" \
        '[$t, $s, .root, .file, .sha256, (.families | join("+")), .holders, (.line | tostring), .statement, (.mentions | tostring)] | @tsv' \
        "$SCANS/$i/trees/$start.licence.json"
    done
  } > "$DEST/licence_root.tsv"
fi
{
  printf 'task\tkind\thidden_failing_first\thidden_passing_after\texisting_files_kept\texisting_files_left_out\tleft_out_reasons\tpartial_fix\tsecond_round_same\n'
  # each task's last try, when it is checked (the exported folder is that try's)
  awk -F'\t' 'NR > 1 && $1 != "-" {if (!($3 in v)) o[++n] = $3; v[$3] = $8; r[$3] = $1 "\t" $3 "\t" $6}
    END {for (i = 1; i <= n; i++) if (v[o[i]] == "checked") print r[o[i]]}' "$T" \
    | while IFS=$'\t' read -r try id kind; do
    jq -r --arg k "$kind" '[.id, $k, (.hidden_failing_first | tostring), (.hidden_passing_after | tostring),
      (.preservation_files | tostring), (.preservation_left_out | length | tostring),
      ([.preservation_left_out[].reason] | unique | join(",") | if . == "" then "-" else . end),
      (if .partial_control.present then "present" else "none" end),
      (if .second_round.same then "yes" else "no" end)] | @tsv' "$OUT/$id/$try/result.json"
  done
} > "$DEST/checked.tsv"
wc -l "$DEST"/*.tsv
