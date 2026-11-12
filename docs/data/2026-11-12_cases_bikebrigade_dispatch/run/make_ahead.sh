#!/usr/bin/env bash
# make_ahead.sh: makes the task folder of each listed pull request through the running controller (make_one.exs: the
# bundle maker, the source check, the import check), one at a time, before any check, so that the maker's refusals
# and the kinds are known early. A made folder is moved to JOB/copied/<id>, where one.sh imports it as it is.
#   make_ahead.sh <number> ...
# Environment: JOB (this job's folder), CTL (the controller's folder; data in CTL/data), NAME (the controller), LIST
# (dispatch), PREFIX (dispatch), REPOSITORY, CENSUS, SCREEN (file names in CTL/data/LIST/tables).
# Writes JOB/out/make_ahead/<number>/ (the maker's files) and JOB/out/make_ahead/made.tsv: number, id, result, reason,
# kind, start, end, seconds.
set -euo pipefail
: "${JOB:?}" "${CTL:?}" "${NAME:?}"
LIST=${LIST:-dispatch}
PREFIX=${PREFIX:-dispatch}
REPOSITORY=${REPOSITORY:-https://github.com/bikebrigade/dispatch}
CENSUS=${CENSUS:-prs_bikebrigade__dispatch.tsv}
SCREEN=${SCREEN:-screen_bikebrigade__dispatch.tsv}
P=$CTL/data/$LIST
O=$JOB/out/make_ahead
mkdir -p "$O" "$JOB/copied"
[ -f "$O/made.tsv" ] || printf 'number\tid\tresult\treason\tkind\tstart\tend\tseconds\n' > "$O/made.tsv"
rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
for n in "$@"; do
  id=$PREFIX-pr-$n
  t0=$(date -Is)
  rm -f "$P/out/$n/make.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$LIST\", \"NUMBER\" => \"$n\", \"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$CENSUS\", \"SCREEN\" => \"$SCREEN\"}); spawn(fn -> Code.eval_file(\"/data/$LIST/make_one.exs\") end)" > /dev/null
  until [ -e "$P/out/$n/make.done" ]; do sleep 2; done
  t1=$(date -Is)
  rm -rf "$O/$n"; mkdir -p "$O/$n"; cp -a "$P/out/$n/." "$O/$n/"
  result=$(awk -F'\t' 'NR == 2 {print $4}' "$O/$n/make.tsv" 2>/dev/null || echo error)
  reason=$(awk -F'\t' 'NR == 2 {print $5}' "$O/$n/make.tsv" 2>/dev/null || echo -)
  kind=-
  if [ "$result" = made ] && [ -d "$P/tasks/$id" ]; then
    kind=$(jq -r .task_kind "$P/tasks/$id/case.json")
    rm -rf "$JOB/copied/$id"
    mv "$P/tasks/$id" "$JOB/copied/$id"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$id" "${result:-error}" "${reason:--}" "$kind" "$t0" "$t1" \
    "$(($(date -d "$t1" +%s) - $(date -d "$t0" +%s)))" >> "$O/made.tsv"
done
cat "$O/made.tsv"
