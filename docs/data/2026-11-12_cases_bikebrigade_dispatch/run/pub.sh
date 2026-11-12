#!/usr/bin/env bash
# pub.sh: the data folder's tables, on the data-mining machine, from this job's folders.
#   - tasks_dispatch.tsv: one line per try (table.sh tasks), with own_images and own_images_docker_bytes: the images
#     the try added that carry this job's label (JOB_LABEL), counted, and the sum of Docker's size of each (sizes
#     overlap: images share layers);
#   - counts.tsv: pull requests per verdict, step and reason, each counted by its last try (table.sh counts);
#   - images.tsv: every image a try added, all jobs' (table.sh images);
#   - made_ahead.tsv: the bundle maker's result for each listed pull request before any check (make_ahead.sh);
#   - list.tsv: every candidate the screening took for this project, newest merged first, with the Elixir/OTP its
#     starting commit names, the screening's class, and this job's outcome by its last try (or elixir_before_1.18);
#   - scans.tsv, licence_files.tsv, holdout_tasks.tsv, deps_flagged.tsv, licence_root.tsv: from the scans of every
#     checked task (scans.sh's folders in SCANS);
#   - checked.tsv: per checked task, from the engine's result of its last try;
#   - kind_rule.tsv: kind_rule.sh on the exported task folders.
# Environment: JOB (this job's folder: run/, tables/, numbers.txt, out/), TASKDIR (the exported task folders),
# JOB_LABEL (key=value), DEST (where to write). SCANS defaults to JOB/out/scans.
set -euo pipefail
: "${JOB:?}" "${TASKDIR:?}" "${JOB_LABEL:?}" "${DEST:?}"
OUT=$JOB/out
SCANS=${SCANS:-$OUT/scans}
RUN=$JOB/run
SCREEN_TSV=$JOB/tables/screen_bikebrigade__dispatch.tsv
mkdir -p "$DEST" "$OUT/tables"
# table.sh reads the made folder of a try for the pair and the kind: the exported folder, else the copied one
TD=$(mktemp -d)
cp -a "$JOB"/copied/. "$TD/"
cp -a "$TASKDIR"/. "$TD/"
for t in tasks counts images; do
  OUT=$OUT NUMBERS=$JOB/numbers.txt PREFIX=dispatch TASKDIR=$TD SCREEN_TSV=$SCREEN_TSV "$RUN/table.sh" "$t" > "$OUT/tables/$t.tsv"
done
rm -rf "$TD"
key=${JOB_LABEL%%=*} val=${JOB_LABEL#*=}
own() { # $1 id, $2 try: the count and bytes of the try's added images that carry the job's label
  local f=$OUT/$1/$2/images_added.tsv n=0 b=0 img bytes l
  if [ -s "$f" ]; then
    while IFS=$'\t' read -r img _names bytes; do
      l=$(docker image inspect "$img" --format "{{index .Config.Labels \"$key\"}}" 2>/dev/null || true)
      if [ "$l" = "$val" ]; then n=$((n + 1)); b=$((b + bytes)); fi
    done < "$f"
  fi
  printf '%s\t%s' "$n" "$b"
}
{
  head -1 "$OUT/tables/tasks.tsv" | tr -d '\n'; printf '\town_images\town_images_docker_bytes\n'
  tail -n +2 "$OUT/tables/tasks.tsv" | while IFS= read -r line; do
    try=$(printf '%s' "$line" | cut -f1) id=$(printf '%s' "$line" | cut -f3)
    if [ "$try" = - ]; then printf '%s\t-\t-\n' "$line"; else printf '%s\t%s\n' "$line" "$(own "$id" "$try")"; fi
  done
} > "$DEST/tasks_dispatch.tsv"
cp "$OUT/tables/counts.tsv" "$OUT/tables/images.tsv" "$DEST/"
cp "$OUT/make_ahead/made.tsv" "$DEST/made_ahead.tsv"
# list: the screening's candidates (classes table) and the outcome of each
{
  printf 'number\tmerged\tstart_commit\telixir_otp_named\tclass\toutcome\tdropped_at\treason\n'
  awk -F'\t' 'NR > 1 {print $2 "\t" substr($3, 1, 10) "\t" $4 "\t" $5 "/" $6 "\t" $7}' "$JOB/tables/classes_dispatch.tsv" |
    while IFS=$'\t' read -r n merged start pair class; do
      last=$(awk -F'\t' -v i="dispatch-pr-$n" '$3 == i {v = $8 "\t" $9 "\t" $10} END {print v}' "$DEST/tasks_dispatch.tsv")
      if [ -n "$last" ]; then o=$last
      elif [ "$class" = elixir_before_1.18 ]; then o=$(printf 'not made\t-\telixir_before_1.18')
      else o=$(printf 'not made\t-\t-'); fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$merged" "$start" "$pair" "$class" "$o"
    done
} > "$DEST/list.tsv"
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
  printf 'task\ttry\tkind\thidden_failing_first\thidden_passing_after\texisting_files_kept\texisting_files_left_out\tleft_out_reasons\tpartial_fix\tsecond_round_same\n'
  awk -F'\t' 'NR > 1 && $1 != "-" {if (!($3 in v)) o[++n] = $3; v[$3] = $8; r[$3] = $3 "\t" $1 "\t" $6}
    END {for (i = 1; i <= n; i++) if (v[o[i]] == "checked") print r[o[i]]}' "$DEST/tasks_dispatch.tsv" \
    | while IFS=$'\t' read -r id try kind; do
    jq -r --arg k "$kind" --arg t "$try" '[.id, $t, $k, (.hidden_failing_first | tostring), (.hidden_passing_after | tostring),
      (.preservation_files | tostring), (.preservation_left_out | length | tostring),
      ([.preservation_left_out[].reason] | unique | join(",") | if . == "" then "-" else . end),
      (if .partial_control.present then "present" else "none" end),
      (if .second_round.same then "yes" else "no" end)] | @tsv' "$OUT/$id/$try/result.json"
  done
} > "$DEST/checked.tsv"
"$RUN/kind_rule.sh" "$TASKDIR" > "$DEST/kind_rule.tsv"
wc -l "$DEST"/*.tsv
