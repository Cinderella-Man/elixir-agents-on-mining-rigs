#!/usr/bin/env bash
# pub.sh: the data folder's tables of this job, on the data-mining machine, from all.sh's output, the scans, the
# candidate list and the project's suite run.
#   - tasks.tsv: tables.sh's tasks_own.tsv (one line per try; the candidates not reached are in candidates.tsv), with
#     two more columns: the database image the starting commit's CI names (list.tsv: the CI workflow's service, or
#     "compose:" and the compose file's image for the postgres service the CI starts with docker compose) and the one
#     the task used (its case.json);
#   - counts.tsv: pull requests per verdict, step and reason, each counted by its last try;
#   - candidates.tsv: every candidate merged since SINCE, newest first: merged, starting commit, Elixir/OTP and Gleam read
#     from the commit (list.tsv), the CI's database, the toolchain resolver's result and reason (resolve.tsv), the kind
#     read ahead (kinds.tsv), and what this job did with it: tried (its last verdict), or the reason it was left out,
#     or "not reached";
#   - left_out.tsv: the candidates per reason they were left out without a try, with whose cause it is;
#   - scans.tsv, licence_files.tsv, holdout_tasks.tsv, deps_flagged.tsv, licence_root.tsv: from the scans of every
#     checked task (scans.sh's folders in SCANS);
#   - checked.tsv: per checked task, from the engine's result of its checked try: the hidden tests that fail first and
#     pass after, the existing test files kept and left out (with the reason), the partial fix, the second round;
#   - project_tests.tsv, project_test_failures.tsv: the project's suite run (suite_tables.sh's tables in SUITE).
# Environment: OUT (all.sh's output folder, with tables/ from tables.sh), SCANS, LIST, RESOLVE, KINDS, SUITE, TASKDIR
# (the made task folders), DEST.
set -euo pipefail
: "${OUT:?}" "${SCANS:?}" "${LIST:?}" "${RESOLVE:?}" "${KINDS:?}" "${SUITE:?}" "${TASKDIR:?}" "${DEST:?}"
mkdir -p "$DEST"
db_used() { jq -r '.services.postgres.image // "-" | sub("@sha256:[0-9a-f]+$"; "")' "$TASKDIR/$1/case.json" 2>/dev/null || echo -; }
{
  head -1 "$OUT/tables/tasks_own.tsv" | tr -d '\n'; printf '\tci_database\tdatabase_used\n'
  tail -n +2 "$OUT/tables/tasks_own.tsv" | awk -F'\t' '$1 != "-"' | while IFS= read -r line; do
    number=$(printf '%s' "$line" | cut -f2) id=$(printf '%s' "$line" | cut -f3)
    ci=$(awk -F'\t' -v n="$number" '$2 == n {print $8}' "$LIST")
    printf '%s\t%s\t%s\n' "$line" "${ci:--}" "$(db_used "$id")"
  done
} > "$DEST/tasks.tsv"
# counts: the last try of each pull request (column 3 the id, 8 verdict, 9 step, 10 reason)
awk -F'\t' 'NR > 1 && $1 != "-" {last[$3] = $8 "\t" $9 "\t" $10} END {for (i in last) print last[i]}' \
  "$DEST/tasks.tsv" | sort | uniq -c | sort -rn \
  | awk 'BEGIN {print "pull_requests\tverdict\tdropped_at\treason"} {c = $1; sub(/^ *[0-9]+ /, ""); print c "\t" $0}' \
  > "$DEST/counts.tsv"
# candidates: list.tsv (repo, number, merged, start, elixir, otp, gleam, database, needs, merge) joined with the
# resolver (number 2, result 5, reason 6), the kind read ahead (number 1, kind 6) and the last try (tasks.tsv)
awk -F'\t' -v OFS='\t' '
  FILENAME == ARGV[1] {if (FNR > 1) {res[$2] = $5; rr[$2] = $6}; next}
  FILENAME == ARGV[2] {if (FNR > 1) kind[$1] = $6; next}
  FILENAME == ARGV[3] {if (FNR > 1 && $1 != "-") {tried[$2] = $8 (($9 != "-") ? " " $9 " " $10 : "")}; next}
  FNR == 1 {print "number", "merged", "start", "elixir", "otp", "gleam", "ci_database", "resolver", "resolver_reason",
    "kind_read_ahead", "this_job"; next}
  {
    r = ($2 in res) ? res[$2] : "-"; why = ($2 in rr) ? rr[$2] : "-"
    if ($2 in tried) job = "tried: " tried[$2]
    else if ($9 != "-") job = "left out: " $9
    else if (r != "resolved") job = "left out: " why
    else job = "not reached"
    print $2, $3, $4, $5, $6, $7, $8, r, why, (($2 in kind) ? kind[$2] : "-"), job
  }' "$RESOLVE" "$KINDS" "$DEST/tasks.tsv" "$LIST" > "$DEST/candidates.tsv"
{
  printf 'candidates\treason\twhose\n'
  awk -F'\t' 'NR > 1 && $11 ~ /^left out: / {sub(/^left out: /, "", $11); n[$11]++} END {for (k in n) print n[k] "\t" k}' \
    "$DEST/candidates.tsv" | sort -rn | while IFS=$'\t' read -r n why; do
    case $why in
      elixir_before_1.18) whose="the dataset's floor" ;;
      no_merge_commit) whose="the census (no merge commit on the default branch)" ;;
      *) whose="the factory's" ;;
    esac
    printf '%s\t%s\t%s\n' "$n" "$why" "$whose"
  done
  awk -F'\t' 'NR > 1 && $11 == "not reached" {n++} END {print n + 0 "\tnot reached\t-"}' "$DEST/candidates.tsv"
} > "$DEST/left_out.tsv"
ids=$(ls "$SCANS" | sed -n 's/\.done$//p' | sort)
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
{
  printf 'task\tkind\thidden_failing_first\thidden_passing_after\texisting_files_kept\texisting_files_left_out\tleft_out_reasons\tpartial_fix\tsecond_round_same\n'
  # each task's last try, when it is checked (the exported folder is that try's)
  awk -F'\t' 'NR > 1 && $1 != "-" {if (!($3 in v)) o[++n] = $3; v[$3] = $8; r[$3] = $1 "\t" $3 "\t" $6}
    END {for (i = 1; i <= n; i++) if (v[o[i]] == "checked") print r[o[i]]}' "$DEST/tasks.tsv" \
    | while IFS=$'\t' read -r try id kind; do
    jq -r --arg k "$kind" '[.id, $k, (.hidden_failing_first | tostring), (.hidden_passing_after | tostring),
      (.preservation_files | tostring), (.preservation_left_out | length | tostring),
      ([.preservation_left_out[].reason] | unique | join(",") | if . == "" then "-" else . end),
      (if .partial_control.present then "present" else "none" end),
      (if .second_round.same then "yes" else "no" end)] | @tsv' "$OUT/$id/$try/result.json"
  done
} > "$DEST/checked.tsv"
cp "$SUITE/project_tests.tsv" "$SUITE/project_test_failures.tsv" "$DEST/"
wc -l "$DEST"/*.tsv
