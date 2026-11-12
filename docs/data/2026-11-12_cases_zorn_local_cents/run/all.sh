#!/usr/bin/env bash
# all.sh: the job's driver on the data-mining machine, one pull request of zorn/local_cents at a time (the driver of
# the nerves_hub_web job on the same machine, cut to this project, with a target count of good cases, a cap on the
# pull requests tried, the two scans after every check, and the balance of the two kinds).
#   all.sh stage   CTL/data/localcents/ with the recipe, the image table, the hold-out list, the census and screen tables
#                  (from JOB/tables) and make_one.exs; the maker's Git cache starts empty there
#   all.sh run     the numbers of JOB/numbers.txt (newest merged first; list.sh), in order, through one.sh into
#                  OUT/<id>/1. After each checked task the licence scan and the hold-out check run on it (scans.sh, into
#                  JOB/scans/<id>/). A task is good when it is checked, its licence result is pass and its hold-out
#                  result is not fail (a `review` is read by a person afterwards). The run stops when TARGET tasks are
#                  good or MAX_TRIES pull requests have been tried. The balance (docs/dataset_rules.md, section 7): once
#                  KIND_AFTER tasks are good and one kind (bug_fix, feature) has fewer than KIND_MIN of them, a candidate
#                  of the other kind is made but deferred (OUT/<id>/k, not a try); the deferred ones run at the end, in
#                  order, when the target is not reached. A pull request whose row exists is not run again; checked
#                  tasks without scans (from an earlier run) are scanned first. The watcher (watch.sh) runs for the
#                  whole run; a stop it writes ends the run at once.
#   all.sh retry N [TRY]  the pull request N once more, into OUT/<id>/TRY (2 by default; 3 for a third try): for a try whose failure was the machine's (a time-out
#                  or a lost database connection), run when the load is lower
# OUT/rows.tsv holds every try's row, the try first (1, 2, or k for a deferral), written again after each try.
# Environment: WORK (the factory's work folder: tasks/), JOB (this job's folder: run/, src/, tables/, numbers.txt,
# local_cents-full.git: a full clone for the scans, whose tree checkouts would otherwise fetch every file of a commit
# one request at a time; bench_cases/), SRC (default JOB/src), CTL, NAME, OUT (default JOB/out), JOB_LABEL, TASK_LABEL, TARGET
# (15), MAX_TRIES (60), KIND_AFTER (10), KIND_MIN (3), and the watcher's settings (MAX_LOAD, MIN_FREE). Writes
# OUT/rows.tsv, OUT/good.tsv, OUT/watch.tsv, OUT/all.done at the end, and one line per start, end and scan to
# standard output.
set -euo pipefail
: "${WORK:?}" "${JOB:?}" "${CTL:?}" "${NAME:?}"
OUT=${OUT:-$JOB/out}
SRC=${SRC:-$JOB/src}
TARGET=${TARGET:-15}
MAX_TRIES=${MAX_TRIES:-60}
KIND_AFTER=${KIND_AFTER:-10}
KIND_MIN=${KIND_MIN:-3}
LIST=localcents
REPOSITORY=https://github.com/zorn/local_cents
PREFIX=local-cents
RECIPE=recipes/zorn__local_cents.json
CENSUS=prs_zorn__local_cents.tsv
SCREEN=screen_zorn__local_cents.tsv
DEST=$WORK/tasks/zorn__local_cents
SCANS=$JOB/scans
step=${1:?stage|run|retry}

case $step in
stage)
  d=$CTL/data/$LIST
  [ ! -e "$d" ] || { echo "$d exists"; exit 1; }
  mkdir -p "$d/tables" "$d/out"
  cp "$SRC/$RECIPE" "$d/recipe.json"
  cp "$SRC/config/toolchain_images.json" "$SRC/config/holdout.json" "$d/"
  cp "$JOB/tables/$CENSUS" "$JOB/tables/$SCREEN" "$d/tables/"
  cp "$JOB/run/make_one.exs" "$d/"
  echo "staged $d"
  ;;
run|retry)
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
        for t in k 1 2 3; do
          r=$OUT/$PREFIX-pr-$m/$t/row.tsv
          [ ! -e "$r" ] || { printf '%s\t' "$t"; cat "$r"; }
        done
      done
    } > "$OUT/rows.tsv"
  }
  last() { # the verdict of each pull request's last try that is not a deferral: id, verdict
    awk -F'\t' 'NR > 1 && $1 != "k" {v[$4] = $10} END {for (i in v) print i "\t" v[i]}' "$OUT/rows.tsv"
  }
  tried() { last | wc -l; }
  scanned() { [ -s "$SCANS/$1/licence.tasks.tsv" ] && [ -s "$SCANS/$1/holdout.tasks.tsv" ]; }
  goods() { # OUT/good.tsv: every checked task with its scan results and kind; prints the number of good ones
    {
      printf 'id\tlicence\tholdout\tkind\tgood\tlong_file_read\n'
      last | awk -F'\t' '$2 == "checked" {print $1}' | sort | while read -r id; do
        lic=$(awk -F'\t' 'NR == 2 {print $8}' "$SCANS/$id/licence.tasks.tsv" 2>/dev/null || true)
        hold=$(awk -F'\t' 'NR == 2 {print $NF}' "$SCANS/$id/holdout.tasks.tsv" 2>/dev/null || true)
        kind=$(jq -r '.task_kind // "-"' "$DEST/$id/case.json" 2>/dev/null || echo -)
        # the rules page, section 9: a licence result that fails only on files the scan left out for their length
        # passes once each such file's changed part is read (SCANS/large_reads.tsv, verdict pass)
        read_ok=-
        if [ "$lic" = fail ]; then
          read_ok=$(awk -F'\t' -v id="$id" 'NR == FNR {if ($1 == id && $8 == "pass") ok[$2] = 1; next}
            FNR > 1 && $6 != "pass" {n++; if ($6 != "fail:exclude:large" || !($2 in ok)) bad++}
            END {print (n > 0 && bad == 0) ? "yes" : "no"}' "$SCANS/large_reads.tsv" "$SCANS/$id/licence.files.tsv" 2>/dev/null || echo no)
        fi
        g=no; { [ "$lic" = pass ] || [ "$read_ok" = yes ]; } && { [ "$hold" = pass ] || [ "$hold" = review ]; } && g=yes
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "${lic:--}" "${hold:--}" "$kind" "$g" "$read_ok"
      done
    } > "$OUT/good.tsv"
    awk -F'\t' 'NR > 1 && $5 == "yes"' "$OUT/good.tsv" | wc -l
  }
  want_kind() { # the kind to prefer, or nothing
    local n b f
    n=$(goods)
    [ "$n" -ge "$KIND_AFTER" ] || return 0
    b=$(awk -F'\t' 'NR > 1 && $5 == "yes" && $4 == "bug_fix"' "$OUT/good.tsv" | wc -l)
    f=$(awk -F'\t' 'NR > 1 && $5 == "yes" && $4 == "feature"' "$OUT/good.tsv" | wc -l)
    if [ "$b" -lt "$KIND_MIN" ]; then echo bug_fix; elif [ "$f" -lt "$KIND_MIN" ]; then echo feature; fi
  }
  scan() { # $1 id: the two scans, once
    scanned "$1" && return 0
    SRC=$SRC TASKS=$DEST IDS=$1 CLONE=$JOB/local_cents-full.git BENCH=$JOB/bench_cases OUT=$SCANS LABELS=$TASK_LABEL,$JOB_LABEL \
      "$JOB/run/scans.sh" run | sed "s/^/$(date -Is) scan /"
  }
  one() { # $1 number, $2 try (1, 2 or k), $3 the kind to prefer (may be empty)
    local n=$1 try=$2 want=${3:-}
    local id=$PREFIX-pr-$n o=$OUT/$PREFIX-pr-$n/$try
    [ ! -e "$o/row.tsv" ] && [ ! -e "$STOP" ] || return 0
    rm -rf "$o"; mkdir -p "$o"
    echo "$(date -Is) start $id try $try${want:+ (prefer $want)}"
    SRC=$SRC CTL=$CTL NAME=$NAME LIST=$LIST NUMBER=$n PREFIX=$PREFIX COPIED=$JOB/copied DEST=$DEST \
      REPOSITORY=$REPOSITORY CENSUS=$CENSUS SCREEN=$SCREEN OUT=$o WATCH=$W STOP=$STOP WANT_KIND=$want \
      "$JOB/run/one.sh" > "$o.log" 2>&1 < /dev/null || { rc=$?; echo "$(date -Is) one.sh $id try $try: exit $rc"; }
    if [ -e "$o/row.tsv" ]; then
      rows
      if [ "$(cut -f9 "$o/row.tsv")" = checked ]; then scan "$id"; fi
      echo "$(date -Is) end $id try $try: $(cut -f9-11,16 "$o/row.tsv" | tr '\t' ' ') (good: $(goods), tried: $(tried))"
    fi
  }
  rows
  for id in $(last | awk -F'\t' '$2 == "checked" {print $1}'); do [ -e "$STOP" ] || scan "$id"; done
  if [ "$step" = run ]; then
    for n in $(cat "$JOB/numbers.txt"); do
      [ "$(goods)" -lt "$TARGET" ] || { echo "$(date -Is) $TARGET good: no further pull request is started"; break; }
      [ "$(tried)" -lt "$MAX_TRIES" ] || { echo "$(date -Is) $MAX_TRIES tried: no further pull request is started"; break; }
      [ ! -e "$OUT/$PREFIX-pr-$n/1/row.tsv" ] || continue
      want=$(want_kind)
      if [ -n "$want" ]; then
        one "$n" k "$want"
        r=$OUT/$PREFIX-pr-$n/k/row.tsv
        if [ -e "$r" ] && [ "$(cut -f9 "$r")" = deferred ]; then continue; fi
        # made and of the wanted kind: the deferral try was the real one; keep it as try 1
        [ -e "$r" ] && { rm -rf "$OUT/$PREFIX-pr-$n/1"; mv "$OUT/$PREFIX-pr-$n/k" "$OUT/$PREFIX-pr-$n/1"; mv "$OUT/$PREFIX-pr-$n/k.log" "$OUT/$PREFIX-pr-$n/1.log"; rows; }
      else
        one "$n" 1
      fi
    done
    # the deferred ones, in order, while the target is not reached
    for n in $(cat "$JOB/numbers.txt"); do
      [ -e "$OUT/$PREFIX-pr-$n/k/row.tsv" ] && [ ! -e "$OUT/$PREFIX-pr-$n/1/row.tsv" ] || continue
      [ "$(goods)" -lt "$TARGET" ] && [ "$(tried)" -lt "$MAX_TRIES" ] || break
      one "$n" 1
    done
  else
    n=${2:?retry N [TRY]}
    t=${3:-2}
    rm -rf "$OUT/$PREFIX-pr-$n/$t"
    one "$n" "$t"
  fi
  touch "$END"
  wait "$watcher" || true
  echo "$(date -Is) good: $(goods), tried: $(tried)"
  if [ -e "$STOP" ]; then echo "$(date -Is) stopped: $(head -1 "$STOP")"; else echo "$(date -Is) all done"; fi
  date -Is > "$OUT/all.done"
  ;;
*) echo "unknown step $step"; exit 2 ;;
esac
