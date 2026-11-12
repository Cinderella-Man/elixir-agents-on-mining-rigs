#!/usr/bin/env bash
# phases.sh: the rest of the run after the target became 20, as rounds of all.sh, one after another. It first waits
# until no all.sh driver of this run is left (one whose working folder is T). Then, round by round:
#   - while the project has fewer than MIN_BUGFIX checked bug fixes (the task_kind of the exported folders in DEST),
#     the order puts the untried candidates the read-ahead calls bug fixes first (newest first), then the rest, and
#     the round ends after one more checked case (TARGET = this run's checked count + 1);
#   - after that, the untried candidates newest first, until TARGET_FINAL cases of this run are checked.
# The tried pull requests head every order (their rows are kept). Before each round the hold list (out/hold.txt) is
# emptied. It ends when TARGET_FINAL is reached, a round adds no row (the candidates are used up), or the watcher
# wrote out/STOP.
# Environment: T (this run's folder: run/, kinds.tsv, out/, logs/), DEST (the exported task folders), TARGET_FINAL,
# MIN_BUGFIX, MAX_TRIED, and for all.sh WORK, CTL, NAME, JOB_LABEL, TASK_LABEL, MAX_LOAD, MIN_FREE.
# Writes T/numbers_round<N>.txt, T/numbers.txt, T/logs/round<N>.start and T/logs/all_round<N>.log, and one line per
# decision to standard output.
set -uo pipefail
: "${T:?}" "${DEST:?}" "${TARGET_FINAL:?}" "${MIN_BUGFIX:?}" "${MAX_TRIED:?}"
cd "$T" || exit 1
FIRST_RUN='^(2118|2119|2113|2112|2109)$'
driver_up() {
  local p
  for p in $(pgrep -fx 'bash run/all.sh run'); do
    [ "$(readlink -f "/proc/$p/cwd" 2>/dev/null)" = "$T" ] && return 0
  done
  return 1
}
checked_in_run() { # the tasks of this run whose last try is checked
  awk -F'\t' 'NR > 1 {v[$4] = $10} END {for (i in v) if (v[i] == "checked") n++; print n + 0}' out/rows.tsv
}
bugfixes() { # the checked bug fixes of the project
  local n=0 c
  for c in "$DEST"/*/case.json; do [ "$(jq -r .task_kind "$c")" = bug_fix ] && n=$((n + 1)); done
  echo "$n"
}
rows_n() { awk 'END {print NR}' out/rows.tsv; }
while driver_up; do sleep 10; done
echo "$(date -Is) no driver left; checked in this run: $(checked_in_run), bug fixes: $(bugfixes)"
round=0
while :; do
  [ ! -e out/STOP ] || { echo "$(date -Is) stopped: $(head -1 out/STOP)"; break; }
  c=$(checked_in_run) b=$(bugfixes)
  [ "$c" -lt "$TARGET_FINAL" ] || { echo "$(date -Is) $c checked in this run: done"; break; }
  round=$((round + 1))
  awk -F'\t' 'NR > 1 && $1 == 1 {print $3}' out/rows.tsv > out/tried.txt
  untried() { # $1: bug_fix, feature or any
    awk -F'\t' -v k="$1" 'NR == FNR {t[$1] = 1; next}
      FNR > 1 && $5 == "-" && !($1 in t) && (k == "any" || $6 == k) {print $1}' out/tried.txt kinds.tsv \
      | grep -vE "$FIRST_RUN"
  }
  if [ "$b" -lt "$MIN_BUGFIX" ]; then
    target=$((c + 1)) order="bug fixes first"
    { cat out/tried.txt; untried bug_fix; untried feature; } > "numbers_round$round.txt"
  else
    target=$TARGET_FINAL order="newest first"
    { cat out/tried.txt; untried any; } > "numbers_round$round.txt"
  fi
  if [ "$(wc -l < "numbers_round$round.txt")" -le "$(wc -l < out/tried.txt)" ]; then
    echo "$(date -Is) no untried candidate left"; break
  fi
  cp "numbers_round$round.txt" numbers.txt
  : > out/hold.txt
  date -Is > "logs/round$round.start"
  before=$(rows_n)
  echo "$(date -Is) round $round: $order, target $target (checked in this run $c, bug fixes $b)"
  env TARGET="$target" MAX_TRIED="$MAX_TRIED" JOB="$T" run/all.sh run > "logs/all_round$round.log" 2>&1 < /dev/null
  echo "$(date -Is) round $round ended: $(tail -1 "logs/all_round$round.log")"
  [ "$(rows_n)" -gt "$before" ] || { echo "$(date -Is) round $round added no row"; break; }
done
echo "$(date -Is) phases done"
