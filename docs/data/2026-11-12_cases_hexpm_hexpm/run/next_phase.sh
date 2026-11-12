#!/usr/bin/env bash
# next_phase.sh: waits until the running phase's driver has ended (out/all.done newer than AFTER, and the process
# DRIVER gone), then writes the next order and starts the next phase of all.sh: the pull requests already tried
# first (their rows are kept), then every untried candidate that needs nothing more, newest merged first (kinds.tsv
# order), without the first run's five (2118, 2119, 2113, 2112, 2109).
# Environment: T (this run's folder: run/, kinds.tsv, out/, logs/), AFTER (the running phase's start marker), DRIVER
# (the running phase's all.sh pid), PHASE (the next phase's name), TARGET and MAX_TRIED (this run's counts), and for
# all.sh WORK, CTL, NAME, JOB_LABEL, TASK_LABEL, MAX_LOAD, MIN_FREE.
# Writes T/numbers_<PHASE>.txt, T/numbers.txt, T/logs/<PHASE>.start and T/logs/all_<PHASE>.log.
set -euo pipefail
: "${T:?}" "${AFTER:?}" "${DRIVER:?}" "${PHASE:?}" "${TARGET:?}" "${MAX_TRIED:?}"
cd "$T"
until [ out/all.done -nt "$AFTER" ] && ! kill -0 "$DRIVER" 2> /dev/null; do sleep 10; done
awk -F'\t' 'NR > 1 && $1 == 1 {print $3}' out/rows.tsv > out/tried.txt
{
  cat out/tried.txt
  awk -F'\t' 'NR == FNR {t[$1] = 1; next} FNR > 1 && $5 == "-" && !($1 in t) {print $1}' out/tried.txt kinds.tsv \
    | grep -vx -e 2118 -e 2119 -e 2113 -e 2112 -e 2109
} > "numbers_$PHASE.txt"
cp "numbers_$PHASE.txt" numbers.txt
date -Is > "logs/$PHASE.start"
exec env TARGET="$TARGET" MAX_TRIED="$MAX_TRIED" JOB="$T" run/all.sh run > "logs/all_$PHASE.log" 2>&1 < /dev/null
