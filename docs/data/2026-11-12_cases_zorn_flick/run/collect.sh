#!/usr/bin/env bash
# collect.sh: the job's published tables, written on the data-mining machine into PUB from the job's own files.
#   cases.tsv            one line per try (table.sh tasks): merge date, Elixir/OTP, kind, verdict, step, reason, the wall
#                        time of each step, the engine's step times, the load, this job's own image bytes, the scans
#                        and whose cause a drop is (CAUSES)
#   counts.tsv           the pull requests by their last try's verdict, step and reason (table.sh counts)
#   good.tsv             every checked task with its licence and hold-out results, its kind and whether it counts
#   scans.tsv            the two scans per checked task: licence file and family, files touched and passing, the
#                        hold-out's repository check, name hits and span counts (no span text)
#   holdout_reviews.tsv  the `review` hits read by a person: span id, the bench case, what was read, the verdict
#   licence_large.tsv    the checked tasks whose licence result fails only on files the scan set aside as too large:
#                        the file, its bytes at both commits, the number of other failing files, and a person's reading
#                        of the changed part (SCANS/large_reads.tsv; the rules page, section 9)
#   deps.tsv             the locked packages over all checked tasks, with their declared licences, class and the
#                        number of tasks that lock them
#   own_images.tsv       every image that carries this job's label: id, names, Docker's size and its unique size
#   causes.tsv           the drops read by a person: whose cause, and why
#   list.tsv             the candidate list (list.sh) with each one's status
#   project_tests.tsv    the project's own suite (suite_tables.sh)
# Environment: JOB (the job's folder), WORK (the factory's work folder), CTL, PUB, JOB_LABEL (key=value).
set -euo pipefail
: "${JOB:?}" "${WORK:?}" "${CTL:?}" "${PUB:?}" "${JOB_LABEL:?}"
OUT=$JOB/out
SCANS=$JOB/scans
DEST=$WORK/tasks/zorn__flick
mkdir -p "$PUB"
docker images -a --no-trunc -q --filter "label=$JOB_LABEL" | sort -u > "$JOB/mine.txt"
causes=$JOB/causes.tsv
[ -e "$causes" ] || printf 'id\tcause\n' > "$causes"
env OUT="$OUT" NUMBERS="$JOB/numbers.txt" PREFIX=flick TASKDIR="$CTL/data/flick/tasks" \
  SCREEN_TSV="$JOB/tables/screen_zorn__flick.tsv" MINE="$JOB/mine.txt" SCANS="$SCANS" CAUSES="$causes" \
  "$JOB/run/table.sh" tasks > "$PUB/cases.tsv"
env OUT="$OUT" NUMBERS="$JOB/numbers.txt" PREFIX=flick TASKDIR="$CTL/data/flick/tasks" \
  SCREEN_TSV="$JOB/tables/screen_zorn__flick.tsv" "$JOB/run/table.sh" counts > "$PUB/counts.tsv"
cp "$OUT/good.tsv" "$PUB/good.tsv"
{
  printf 'task\tstart\tlicence_file\tlicence_families\tfiles_touched\tfiles_passing\tlicence_result\trepository_check\tname_hits\tspans8\tspans8_common\tspans8_syntax\tspans8_own_tree\tspans8_to_read\tspans12\tspans12_to_read\tholdout_result\n'
  for d in "$SCANS"/*/; do
    id=$(basename "$d"); [ "$id" != work ] || continue
    [ -s "$d/licence.tasks.tsv" ] && [ -s "$d/holdout.tasks.tsv" ] || continue
    paste <(awk -F'\t' 'NR == 2 {print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $6 "\t" $7 "\t" $8}' "$d/licence.tasks.tsv") \
      <(awk -F'\t' 'NR == 2 {print $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10 "\t" $14 "\t" $15}' "$d/holdout.tasks.tsv")
  done
} > "$PUB/scans.tsv"
[ ! -e "$SCANS/reviews.tsv" ] || cp "$SCANS/reviews.tsv" "$PUB/holdout_reviews.tsv"
# the checked tasks whose licence result fails only on files the scan set aside as too large (exclude:large): each
# such file with its size in bytes at the starting and the merge commit (from the full clone), and the other findings
{
  printf 'task\tpath\tbytes_start\tbytes_merge\tverdict_start\tverdict_merge\tother_failing_files\twhat_the_file_is\tlines_added\tlines_removed\twhat_the_changed_part_holds\tnotice_or_copyright_lines\tread_verdict\n'
  for d in "$SCANS"/*/; do
    id=$(basename "$d"); [ "$id" != work ] || continue
    f=$d/licence.files.tsv; [ -s "$f" ] || continue
    awk -F'\t' 'NR > 1 && $6 != "pass"' "$f" > "$JOB/fails.tmp"
    [ -s "$JOB/fails.tmp" ] || continue
    others=$(awk -F'\t' '$6 != "fail:exclude:large"' "$JOB/fails.tmp" | wc -l)
    start=$(awk -F'\t' 'NR == 2 {print $3}' "$d/revisions.tsv"); fixed=$(awk -F'\t' 'NR == 2 {print $4}' "$d/revisions.tsv")
    awk -F'\t' '$6 == "fail:exclude:large" {print $2 "\t" $4 "\t" $5}' "$JOB/fails.tmp" | while IFS=$'\t' read -r path vs vm; do
      bs=$(git --git-dir "$JOB/flick.git" cat-file -s "$start:$path" 2>/dev/null || echo -)
      bm=$(git --git-dir "$JOB/flick.git" cat-file -s "$fixed:$path" 2>/dev/null || echo -)
      readrow=$(awk -F'\t' -v id="$id" -v p="$path" '$1 == id && $2 == p {print $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8; f = 1; exit} END {if (!f) print "-\t-\t-\t-\t-\tnot read yet"}' "$SCANS/large_reads.tsv" 2>/dev/null || printf '-\t-\t-\t-\t-\tnot read yet')
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$bs" "$bm" "$vs" "$vm" "$others" "$readrow"
    done
  done
  rm -f "$JOB/fails.tmp"
} > "$PUB/licence_large.tsv"
{
  printf 'kind\tpackage\tversion\tlicences\tclass\ttasks\n'
  for d in "$SCANS"/*/; do [ "$(basename "$d")" != work ] && [ -s "$d/deps.tsv" ] && tail -n +2 "$d/deps.tsv" || true; done |
    awk -F'\t' '{k = $1 FS $2 FS $3 FS $4 FS $5; t[k] += $6} END {for (k in t) print k "\t" t[k]}' | sort
} > "$PUB/deps.tsv"
{
  printf 'image_id\tnames\tbytes\tunique_size_docker\n'
  # exact bytes from the image itself; the unique size (the layers no other image shares) as Docker prints it, rounded
  docker system df -v --format '{{json .Images}}' | jq -r '.[] | [.ID, .UniqueSize] | @tsv' | sort -u > "$JOB/unique.tsv"
  while read -r i; do
    printf '%s\t%s\t%s\t%s\n' "$i" "$(docker image inspect "$i" --format '{{join .RepoTags " "}}')" \
      "$(docker image inspect "$i" --format '{{.Size}}')" "$(awk -F'\t' -v i="$i" '$1 == i {print $2; exit}' "$JOB/unique.tsv")"
  done < "$JOB/mine.txt"
} > "$PUB/own_images.tsv"
cp "$JOB/tables/list.tsv" "$PUB/list.tsv"
cp "$causes" "$PUB/causes.tsv"
cp "$JOB/suite_tables/project_tests.tsv" "$PUB/project_tests.tsv"
wc -l "$PUB"/*.tsv
