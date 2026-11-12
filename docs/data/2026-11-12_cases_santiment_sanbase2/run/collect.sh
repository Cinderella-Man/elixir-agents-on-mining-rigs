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
DEST=$WORK/tasks/santiment__sanbase2
mkdir -p "$PUB"
docker images -a --no-trunc -q --filter "label=$JOB_LABEL" | sort -u > "$JOB/mine.txt"
causes=$JOB/causes.tsv
[ -e "$causes" ] || printf 'id\tcause\n' > "$causes"
env OUT="$OUT" NUMBERS="$JOB/numbers.txt" PREFIX=sanbase2 TASKDIR="$CTL/data/sanbase2/tasks" \
  SCREEN_TSV="$JOB/tables/screen_santiment__sanbase2.tsv" MINE="$JOB/mine.txt" SCANS="$SCANS" CAUSES="$causes" \
  "$JOB/run/table.sh" tasks > "$PUB/cases.tsv"
env OUT="$OUT" NUMBERS="$JOB/numbers.txt" PREFIX=sanbase2 TASKDIR="$CTL/data/sanbase2/tasks" \
  SCREEN_TSV="$JOB/tables/screen_santiment__sanbase2.tsv" "$JOB/run/table.sh" counts > "$PUB/counts.tsv"
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
