#!/usr/bin/env bash
# all.sh: the job's driver on the data-mining machine, one pull request of source-academy/backend at a time (the
# driver of docs/data/2026-11-12_cases_hexpm_hexpm, with this project's names).
#   all.sh stage   CTL/data/LIST/ (LIST: backend) with the recipe RECIPE_FILE (default SRC/recipes/source-academy__backend.json),
#                  the image table, the hold-out list, the census and screen tables (from JOB/tables), make_one.exs and a
#                  copy of the maker's Git cache CACHE (a folder holding source-academy__backend.git); and JOB/copied/ with
#                  the earlier job's task folders of the listed numbers found in the folders COPY (space-separated; empty:
#                  every folder is made again). A second LIST with another RECIPE_FILE serves the numbers JOB/lists.tsv
#                  gives it
#   all.sh run     every number of JOB/numbers.txt, in order, through one.sh (with the LIST that JOB/lists.tsv, "number
#                  list" lines, names for it, else LIST) into OUT/<id>/1, until TARGET tasks are
#                  checked or MAX_TRIED pull requests have been tried (both counted in OUT only); a try whose row
#                  shows the machine's failure (a time-out, a lost database connection, a lost image: "content
#                  digest ... not found") is run again at once, into OUT/<id>/2. Then once more, into OUT/<id>/2, each
#                  one whose check was not settled (the load reached SETTLE_LOAD during it). A pull request whose row
#                  exists is not run again. OUT/rows.tsv holds every
#                  try's row, the try first. The watcher (watch.sh) runs for the whole run; a stop it writes ends the
#                  run at once.
# Environment: WORK (the factory's work folder: tasks/), JOB (this job's folder: run/, src/, tables/, numbers.txt),
# SRC (default JOB/src), CTL, NAME, OUT (default JOB/out), JOB_LABEL, TASK_LABEL, TARGET (3), MAX_TRIED (12); for
# the watcher MAX_LOAD (26) and MIN_FREE (50,000,000,000); for stage CACHE and
# COPY. Writes OUT/rows.tsv (again after each try), OUT/watch.tsv, OUT/all.done at the end, and one line per start
# and end to standard output.
set -euo pipefail
: "${WORK:?}" "${JOB:?}" "${CTL:?}" "${NAME:?}"
OUT=${OUT:-$JOB/out}
SRC=${SRC:-$JOB/src}
TARGET=${TARGET:-3}
MAX_TRIED=${MAX_TRIED:-12}
export MAX_LOAD=${MAX_LOAD:-26} MIN_FREE=${MIN_FREE:-50000000000}
LIST=${LIST:-backend}
REPOSITORY=https://github.com/source-academy/backend
PREFIX=backend
RECIPE=recipes/source-academy__backend.json
CENSUS=prs_source-academy__backend.tsv
SCREEN=screen_source-academy__backend.tsv
DEST=$WORK/tasks/source-academy__backend
step=${1:?stage|run}

case $step in
stage)
  : "${CACHE:?}"
  d=$CTL/data/$LIST
  [ ! -e "$d" ] || { echo "$d exists"; exit 1; }
  mkdir -p "$d/tables" "$d/out" "$JOB/copied"
  cp "${RECIPE_FILE:-$SRC/$RECIPE}" "$d/recipe.json"
  cp "$SRC/config/toolchain_images.json" "$SRC/config/holdout.json" "$d/"
  cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$d/tables/"
  cp "$JOB/run/make_one.exs" "$d/"
  cp -a "$CACHE" "$d/cache"
  for n in $(cat "$JOB/numbers.txt"); do
    for src in ${COPY:-}; do
      if [ -d "$src/$PREFIX-pr-$n" ]; then cp -a "$src/$PREFIX-pr-$n" "$JOB/copied/"; break; fi
    done
  done
  echo "staged $d; copied: $(ls "$JOB/copied" | tr '\n' ' ')"
  ;;
run)
  : "${JOB_LABEL:?}" "${TASK_LABEL:?}"
  mkdir -p "$OUT"
  STOP=$OUT/STOP END=$OUT/watch.end
  rm -f "$END"
  [ ! -e "$STOP" ] || { echo "$STOP exists: $(head -1 "$STOP")"; exit 1; }
  END=$END STOP=$STOP CTL=$CTL NAME=$NAME JOB_LABEL=$JOB_LABEL TASK_LABEL=$TASK_LABEL \
    setsid "$JOB/run/watch.sh" >> "$OUT/watch.tsv" 2> "$OUT/watch.err" < /dev/null &
  watcher=$!
  W=$OUT/watch.tsv
  rows() { # OUT/rows.tsv written again from every try's row.tsv, in the order of numbers.txt
    local m t r
    {
      printf 'try\trepository\tnumber\tid\tfolder\tmake_s\timport_s\tcheck_s\texport_s\tverdict\tdropped_at\treason\tsteps_ms\tload_start\tload_end\tload_max_check\tsettled\timages_added\timages_bytes\tcache_bytes_before\tcache_bytes_after\tfree_before\tfree_after\tjob\tstart\tend\tdetail\n'
      for m in $(cat "$JOB/numbers.txt"); do
        for t in 1 2; do
          r=$OUT/$PREFIX-pr-$m/$t/row.tsv
          [ ! -e "$r" ] || { printf '%s\t' "$t"; cat "$r"; }
        done
      done
    } > "$OUT/rows.tsv"
  }
  checked() { # tasks whose last try is checked
    awk -F'\t' 'NR > 1 {v[$4] = $10} END {for (i in v) if (v[i] == "checked") n++; print n + 0}' "$OUT/rows.tsv"
  }
  tried() { # pull requests with a first try
    awk -F'\t' 'NR > 1 && $1 == 1 {n++} END {print n + 0}' "$OUT/rows.tsv"
  }
  one() { # $1 number, $2 try
    local n=$1 try=$2
    local id=$PREFIX-pr-$n o=$OUT/$PREFIX-pr-$n/$try
    [ ! -e "$o/row.tsv" ] && [ ! -e "$STOP" ] || return 0
    mkdir -p "$o"
    echo "$(date -Is) start $id try $try"
    local list=$LIST l
    if [ -f "$JOB/lists.tsv" ]; then l=$(awk -v n="$n" '$1 == n {print $2}' "$JOB/lists.tsv"); [ -z "$l" ] || list=$l; fi
    SRC=$SRC CTL=$CTL NAME=$NAME LIST=$list NUMBER=$n PREFIX=$PREFIX COPIED=$JOB/copied DEST=$DEST \
      REPOSITORY=$REPOSITORY CENSUS=$CENSUS SCREEN=$SCREEN OUT=$o WATCH=$W STOP=$STOP \
      "$JOB/run/one.sh" > "$o.log" 2>&1 < /dev/null || { rc=$?; echo "$(date -Is) one.sh $id try $try: exit $rc"; }
    if [ -e "$o/row.tsv" ]; then
      rows
      echo "$(date -Is) end $id try $try: $(cut -f9-11,16 "$o/row.tsv" | tr '\t' ' ') (checked: $(checked))"
    fi
  }
  machine() { # $1 a row.tsv: not checked, and its reason or detail shows the machine's failure
    awk -F'\t' '{v = $9; s = tolower($11 " " $NF)}
      END {exit !(v != "checked" && s ~ /content digest|dbconnection|connection (refused|closed|lost|not available)|timed? ?out|timeout/)}' "$1"
  }
  rows
  for n in $(cat "$JOB/numbers.txt"); do
    [ "$(checked)" -lt "$TARGET" ] || { echo "$(date -Is) $TARGET checked: no further pull request is started"; break; }
    [ "$(tried)" -lt "$MAX_TRIED" ] || { echo "$(date -Is) $MAX_TRIED tried: no further pull request is started"; break; }
    one "$n" 1
    r=$OUT/$PREFIX-pr-$n/1/row.tsv
    if [ -e "$r" ] && [ ! -e "$STOP" ] && machine "$r"; then
      echo "$(date -Is) $PREFIX-pr-$n: the machine's failure, run again"
      one "$n" 2
    fi
  done
  for n in $(cat "$JOB/numbers.txt"); do
    r=$OUT/$PREFIX-pr-$n/1/row.tsv
    if [ -e "$r" ] && [ "$(cut -f16 "$r")" = "not settled" ]; then one "$n" 2; fi
  done
  touch "$END"
  wait "$watcher" || true
  if [ -e "$STOP" ]; then echo "$(date -Is) stopped: $(head -1 "$STOP")"; else echo "$(date -Is) all done"; fi
  date -Is > "$OUT/all.done"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
