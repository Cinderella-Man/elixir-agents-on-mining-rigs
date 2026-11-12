#!/usr/bin/env bash
# suite.sh: the project's own suite once at one pull request's starting commit (env_tests.sh probe, prepare, tests),
# with the job's watcher (watch.sh: free space, load, a bench run) running meanwhile. A stop it writes ends the waits.
# Environment: as env_tests.sh (JOB, DATA, GIT_DIR, NAME, NUMBER, MERGE, IMAGE, ROUNDS, SUB), and OUT (where the log
# and the watcher's samples go), CTL, JOB_LABEL, TASK_LABEL. Writes OUT/suite.log, OUT/suite_watch.tsv and last
# OUT/suite.done (the exit code and the time).
set -uo pipefail
: "${JOB:?}" "${OUT:?}" "${CTL:?}" "${NAME:?}" "${JOB_LABEL:?}" "${TASK_LABEL:?}"
mkdir -p "$OUT"
export STOP=$OUT/STOP
END=$OUT/suite_watch.end
rm -f "$END" "$OUT/suite.done"
[ ! -e "$STOP" ] || { echo "$STOP exists: $(head -1 "$STOP")"; exit 1; }
END=$END STOP=$STOP CTL=$CTL NAME=$NAME JOB_LABEL=$JOB_LABEL TASK_LABEL=$TASK_LABEL \
  setsid "$JOB/run/watch.sh" >> "$OUT/suite_watch.tsv" 2> "$OUT/suite_watch.err" < /dev/null &
watcher=$!
rc=0
{
  "$JOB/run/env_tests.sh" probe && "$JOB/run/env_tests.sh" prepare && "$JOB/run/env_tests.sh" tests
} >> "$OUT/suite.log" 2>&1 || rc=$?
touch "$END"
wait "$watcher" || true
echo "$rc $(date -Is)" > "$OUT/suite.done"
