#!/usr/bin/env bash
# compare.sh: per-test comparison of two jobs' runs written by test.sh (OUT/tests/<tag>.tsv, one line per test).
#   compare.sh OLD_UNIT OLD_DOCKER NEW_UNIT NEW_DOCKER [CAUSES] > tests_compared.tsv
# CAUSES (optional) is a table with file, test in its first two columns and a failure's cause in its sixth, such as
# job T0's tests_per_test.tsv; its cause is added as the last column.
# Columns: file, test, the state in each of the four runs ("-" when the run has no such test), and the verdict:
#   same                          the test exists in the new runs and ends as in the old ones, in both
#   differs                       the test exists in both and ends otherwise in at least one run
#   gone: file removed            the test's file is no longer in SRC
#   gone: test removed            the file is still in SRC, the test is not
#   new                           the test is only in the new runs
# Environment: WORK (OUT defaults to WORK/out, SRC to WORK/src).
set -euo pipefail
: "${WORK:?WORK=<work folder>}"
OUT=${OUT:-$WORK/out}
SRC=${SRC:-$WORK/src}
causes=${5:-/dev/null}
awk -F'\t' -v OFS='\t' -v src="$SRC" '
  FILENAME == ARGV[1] { if (FNR > 1) cause[$1 SUBSEP $2] = $6; next }
  FNR == 1 { run++ }
  $4 == "module_failed" { next }
  {
    key = $1 SUBSEP $3
    if (!(key in seen)) { seen[key] = 1; order[++n] = key }
    state[run, key] = $4
  }
  function st(r, k) { return ((r, k) in state) ? state[r, k] : "-" }
  END {
    print "file", "test", "old_unit", "old_docker", "new_unit", "new_docker", "verdict", "old_cause"
    for (i = 1; i <= n; i++) {
      key = order[i]; split(key, part, SUBSEP)
      a = st(1, key); b = st(2, key); c = st(3, key); d = st(4, key)
      old = (a != "-" || b != "-"); new = (c != "-" || d != "-")
      if (old && !new)
        verdict = (system("test -f \"" src "/" part[1] "\"") == 0) ? "gone: test removed" : "gone: file removed"
      else if (!old) verdict = "new"
      else verdict = (a == c && b == d) ? "same" : "differs"
      print part[1], part[2], a, b, c, d, verdict, cause[key]
    }
  }
' "$causes" "$OUT/tests/${1:?OLD_UNIT}.tsv" "$OUT/tests/${2:?OLD_DOCKER}.tsv" "$OUT/tests/${3:?NEW_UNIT}.tsv" \
  "$OUT/tests/${4:?NEW_DOCKER}.tsv" |
  { IFS= read -r header; echo "$header"; sort; }
