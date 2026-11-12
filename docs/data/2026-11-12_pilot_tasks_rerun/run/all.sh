#!/usr/bin/env bash
# all.sh: the job's driver on the data-mining machine, one pull request at a time.
#   all.sh stage   for each list (radiator, ex338): CTL/data/hb3-<list>/ with the template, the image table, the
#                  hold-out list, the census and screen tables (from JOB/tables), make_one.exs and a copy of the
#                  maker's Git cache CACHE_<list>; and JOB/copied/<list>/ with the earlier jobs' task folders of the
#                  listed numbers found in the folders COPY_<list> (space-separated)
#   all.sh run     every line of JOB/numbers.tsv (list, number), in order, through one.sh into OUT/<id>/1; then once
#                  more, into OUT/<id>/2, each one whose check was not settled (the load reached SETTLE_LOAD during
#                  it). A pull request whose row exists is not run again. OUT/rows.tsv holds every try's row, the try
#                  first. The watcher (watch.sh) runs for the whole run; a stop it writes ends the run at once.
# Environment: WORK (the factory's work folder: src/, tasks/), JOB (this job's folder: run/, tables/, numbers.tsv),
# CTL, NAME, OUT (default JOB/out), JOB_LABEL, TASK_LABEL; for stage CACHE_radiator, CACHE_ex338, COPY_radiator,
# COPY_ex338. Writes OUT/rows.tsv (again after each try), OUT/watch.tsv, OUT/all.done at the end, and one line per
# start and end to standard output.
set -euo pipefail
: "${WORK:?}" "${JOB:?}" "${CTL:?}" "${NAME:?}"
OUT=${OUT:-$JOB/out}
SRC=$WORK/src
step=${1:?stage|run}

list_env() {
  case $1 in
  radiator) echo REPOSITORY=https://github.com/podlove/radiator PREFIX=radiator RECIPE=recipes/podlove__radiator.json \
    CENSUS=prs_podlove__radiator.tsv SCREEN=screen_podlove__radiator.tsv DEST="$WORK/tasks/podlove__radiator.retry" ;;
  ex338) echo REPOSITORY=https://github.com/axelclark/ex338 PREFIX=ex338 RECIPE=recipes/axelclark__ex338.json \
    CENSUS=prs_axelclark__ex338.tsv SCREEN=screen_axelclark__ex338.tsv DEST="$WORK/tasks/axelclark__ex338.redis" ;;
  *) echo "unknown list $1" >&2; return 1 ;;
  esac
}

case $step in
stage)
  for list in radiator ex338; do
    eval "$(list_env $list)"
    d=$CTL/data/hb3-$list
    [ ! -e "$d" ] || { echo "$d exists"; exit 1; }
    mkdir -p "$d/tables" "$d/out" "$JOB/copied/$list"
    cp "$SRC/$RECIPE" "$d/recipe.json"
    cp "$SRC/config/toolchain_images.json" "$SRC/config/holdout.json" "$d/"
    cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$d/tables/"
    cp "$JOB/run/make_one.exs" "$d/"
    cache_var=CACHE_$list; copy_var=COPY_$list
    cp -a "${!cache_var:?}" "$d/cache"
    for n in $(awk -v l=$list '$1 == l {print $2}' "$JOB/numbers.tsv"); do
      for src in ${!copy_var:-}; do
        if [ -d "$src/$PREFIX-pr-$n" ]; then cp -a "$src/$PREFIX-pr-$n" "$JOB/copied/$list/"; break; fi
      done
    done
    echo "$list: staged $d; copied: $(ls "$JOB/copied/$list" | tr '\n' ' ')"
  done
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
  rows() { # OUT/rows.tsv written again from every try's row.tsv, in the order of numbers.tsv
    local l m t r
    {
      printf 'try\trepository\tnumber\tid\tfolder\tmake_s\timport_s\tcheck_s\texport_s\tverdict\tdropped_at\treason\tsteps_ms\tload_start\tload_end\tload_max_check\tsettled\timages_added\timages_bytes\tcache_bytes_before\tcache_bytes_after\tfree_before\tfree_after\tjob\tstart\tend\tdetail\n'
      while read -r l m; do
        eval "$(list_env "$l")"
        for t in 1 2; do
          r=$OUT/$PREFIX-pr-$m/$t/row.tsv
          [ ! -e "$r" ] || { printf '%s\t' "$t"; cat "$r"; }
        done
      done < "$JOB/numbers.tsv"
    } > "$OUT/rows.tsv"
  }
  one() { # $1 list, $2 number, $3 try
    local list=$1 n=$2 try=$3
    eval "$(list_env "$list")"
    local id=$PREFIX-pr-$n o=$OUT/$PREFIX-pr-$n/$try
    [ ! -e "$o/row.tsv" ] && [ ! -e "$STOP" ] || return 0
    mkdir -p "$o"
    echo "$(date -Is) start $id try $try"
    SRC=$SRC CTL=$CTL NAME=$NAME LIST=hb3-$list NUMBER=$n PREFIX=$PREFIX COPIED=$JOB/copied/$list DEST=$DEST \
      REPOSITORY=$REPOSITORY CENSUS=$CENSUS SCREEN=$SCREEN OUT=$o WATCH=$W STOP=$STOP \
      "$JOB/run/one.sh" > "$o.log" 2>&1 < /dev/null || { rc=$?; echo "$(date -Is) one.sh $id try $try: exit $rc"; }
    if [ -e "$o/row.tsv" ]; then
      rows
      echo "$(date -Is) end $id try $try: $(cut -f9-11,16 "$o/row.tsv" | tr '\t' ' ')"
    fi
  }
  rows
  while read -r list n; do one "$list" "$n" 1; done < "$JOB/numbers.tsv"
  while read -r list n; do
    eval "$(list_env "$list")"
    r=$OUT/$PREFIX-pr-$n/1/row.tsv
    if [ -e "$r" ] && [ "$(cut -f16 "$r")" = "not settled" ]; then one "$list" "$n" 2; fi
  done < "$JOB/numbers.tsv"
  touch "$END"
  wait "$watcher" || true
  if [ -e "$STOP" ]; then echo "$(date -Is) stopped: $(head -1 "$STOP")"; else echo "$(date -Is) all done"; fi
  date -Is > "$OUT/all.done"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
