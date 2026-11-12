#!/usr/bin/env bash
# per_test.sh: one line per test across three runs written by test.sh (OUT/tests/<tag>.tsv), with the cause of each
# failure read from its reason.
#   per_test.sh UNIT_TAG DOCKER_TAG NEW_TAG > tests_per_test.tsv
# Columns: file, test, the state in each run (passed, failed, excluded, invalid; "-" when the run has no such test),
# and the cause of a failure:
#   its file was not copied: <path>   the test reads a file of the bench that the factory did not copy
#   needs the bench's cases            the test reads a bench case, or needs a non-empty case inventory
#   other                              anything else
# Environment: WORK (OUT defaults to WORK/out).
set -euo pipefail
: "${WORK:?WORK=<work folder>}"
OUT=${OUT:-$WORK/out}
awk -F'\t' -v OFS='\t' '
  FNR == 1 { run++ }
  $4 == "module_failed" { next }
  {
    key = $1 SUBSEP $3
    if (!(key in seen)) { seen[key] = 1; order[++n] = key }
    state[run, key] = $4
    if ($4 == "failed" && !(key in why)) why[key] = $5
  }
  function cause(r) {
    if (r == "") return ""
    if (r ~ /\/app\/results-page\//) return "its file was not copied: results-page/index.html"
    if (r ~ /install-claude-code-kit\.sh/) return "its file was not copied: scripts/install-claude-code-kit.sh"
    if (r ~ /Unknown benchmark case|Invalid release case inventory|\/app\/cases\/|Invalid or duplicated case IDs|full frozen inventory|plausible-pr-5939|not a nonempty list|ids != \[\]|right hand side value: \[\] |assert_receive \{:started, run\}|Enum\.count\(replies/)
      return "needs the bench'"'"'s cases"
    return "other"
  }
  END {
    print "file", "test", "unit_unchanged", "docker_unchanged", "docker_with_new_tests", "cause"
    for (i = 1; i <= n; i++) {
      key = order[i]; split(key, part, SUBSEP)
      a = ((1, key) in state) ? state[1, key] : "-"
      b = ((2, key) in state) ? state[2, key] : "-"
      c = ((3, key) in state) ? state[3, key] : "-"
      print part[1], part[2], a, b, c, cause(why[key])
    }
  }
' "$OUT/tests/${1:?UNIT_TAG}.tsv" "$OUT/tests/${2:?DOCKER_TAG}.tsv" "$OUT/tests/${3:?NEW_TAG}.tsv" |
  { IFS= read -r header; echo "$header"; sort; }
