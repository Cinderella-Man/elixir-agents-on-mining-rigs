#!/usr/bin/env bash
# table.sh: per-file counts of two test runs written by test.sh (OUT/tests/<tag>.tsv, one line per test).
#   table.sh UNIT_TAG DOCKER_TAG > counts.tsv
# Columns: file, then tests, passed, failed, excluded or skipped for each run. A module whose setup_all failed
# (state module_failed) is counted as failed tests through its "invalid" lines, so that line itself is not counted.
# Environment: WORK (OUT defaults to WORK/out).
set -euo pipefail
: "${WORK:?WORK=<work folder>}"
OUT=${OUT:-$WORK/out}
unit=${1:?UNIT_TAG}
docker=${2:?DOCKER_TAG}
awk -F'\t' -v OFS='\t' '
  FNR == 1 { run++ }
  $4 == "module_failed" { next }
  {
    f = $1; files[f] = 1; n[run, f]++
    if ($4 == "passed") p[run, f]++
    else if ($4 == "failed" || $4 == "invalid") x[run, f]++
    else e[run, f]++
  }
  END {
    print "file", "unit_tests", "unit_passed", "unit_failed", "unit_excluded",
      "docker_tests", "docker_passed", "docker_failed", "docker_excluded"
    for (f in files)
      print f, n[1, f] + 0, p[1, f] + 0, x[1, f] + 0, e[1, f] + 0, n[2, f] + 0, p[2, f] + 0, x[2, f] + 0, e[2, f] + 0
  }
' "$OUT/tests/$unit.tsv" "$OUT/tests/$docker.tsv" | sort
