#!/usr/bin/env bash
# suite_tables.sh: the tables of the project's own test runs (env_tests.sh tests), from the files tests.exs wrote.
#   project_tests.tsv          one row per run: the engine's verdict and counts, ExUnit's own summary line, the size of
#                              the output against the engine's 2 MiB limit, and test identities the reporter printed
#                              more than once (ExUnit's `parameterize:` runs a module once per parameter set under the
#                              same names)
#   project_test_failures.tsv  every test that failed in either run: its state in each run, its file and line, and the
#                              first error line ExUnit printed for it
# Environment: D (the folder with suite_round<n>.json and .txt), OUT (where the two tables go), ROUNDS (2).
set -euo pipefail
: "${D:?}" "${OUT:?}"
ROUNDS=${ROUNDS:-2}
mkdir -p "$OUT"
printf 'run\tcommand\treturncode\tengine_completed\tengine_passed\tengine_ms\treporter_rows\treporter_distinct\tduplicated_identities\texunit_tests\texunit_passed\texunit_failed\texunit_excluded\texunit_skipped\texunit_seconds\toutput_bytes\tunder_2_mib\n' \
  > "$OUT/project_tests.tsv"
for r in $(seq "$ROUNDS"); do
  t=$D/suite_round$r.txt
  j=$D/suite_round$r.json
  rows=$(grep -c '^EAB_TEST:' "$t")
  distinct=$(grep '^EAB_TEST:' "$t" | cut -d: -f3 | sort -u | wc -l)
  dup=$(grep '^EAB_TEST:' "$t" | cut -d: -f3 | sort | uniq -d | wc -l)
  # ExUnit's summary: "Result: P/T passed, ..." (the pilot's Elixir), "Result: P passed[, F failed] (D doctests,
  # N tests)[, X excluded]" (Elixir 1.20.4), or "[D doctests, ]N tests, F failures[, X excluded][, S skipped]"
  # (Elixir 1.18, whose count of tests includes the excluded and skipped ones)
  result=$(grep -m1 '^Result:' "$t" || true)
  skipped=0
  if [[ $result =~ ^Result:\ ([0-9]+)/([0-9]+)\ passed ]]; then
    passed=${BASH_REMATCH[1]}; total=${BASH_REMATCH[2]}; failed=$((total - passed))
    excluded=$(sed -nE 's/.*, ([0-9]+) excluded.*/\1/p' <<< "$result")
  elif [ -n "$result" ]; then
    passed=$(sed -nE 's/^Result: ([0-9]+) passed.*/\1/p' <<< "$result")
    failed=$(sed -nE 's/.* ([0-9]+) failed.*/\1/p' <<< "$result")
    failed=${failed:-0}; total=$((passed + failed))
    excluded=$(sed -nE 's/.*, ([0-9]+) excluded.*/\1/p' <<< "$result")
  else
    result=$(grep -m1 -E '^([0-9]+ (doctests?|propert(y|ies)), )*[0-9]+ tests?, [0-9]+ failures?' "$t")
    total=$(grep -oE '[0-9]+ (doctests?|propert(y|ies)|tests?)' <<< "$result" | awk '{s += $1} END {print s + 0}')
    failed=$(sed -nE 's/.* ([0-9]+) failures?.*/\1/p' <<< "$result")
    excluded=$(sed -nE 's/.*, ([0-9]+) excluded.*/\1/p' <<< "$result")
    skipped=$(sed -nE 's/.*, ([0-9]+) skipped.*/\1/p' <<< "$result")
    skipped=${skipped:-0}
    passed=$((total - failed - ${excluded:-0} - skipped))
  fi
  seconds=$(grep -m1 '^Finished in' "$t" | sed -E 's/^Finished in ([0-9.]+) seconds.*/\1/')
  bytes=$(stat -c %s "$t")
  jq -r --arg r "$r" --arg rows "$rows" --arg distinct "$distinct" --arg dup "$dup" --arg total "$total" \
    --arg passed "$passed" --arg failed "$failed" --arg excluded "${excluded:-0}" --arg skipped "$skipped" \
    --arg seconds "$seconds" --arg bytes "$bytes" '
    [$r, .command, .returncode, .completed, .passed, .ms, $rows, $distinct, $dup, $total, $passed,
     $failed, $excluded, $skipped, $seconds, $bytes,
     (if ($bytes | tonumber) < 2097152 then "yes" else "no" end)] | map(tostring) | @tsv' "$j" \
    >> "$OUT/project_tests.tsv"
done

# Failures: ExUnit prints "  N) test NAME (MODULE)", then "     FILE:LINE", then the error.
for r in $(seq "$ROUNDS"); do
  grep -v '^EAB_' "$D/suite_round$r.txt" | awk -v r="$r" '
    /^ +[0-9]+\) test / {
      if (name != "") print r "\t" name "\t" where "\t" err
      line = $0; sub(/^ +[0-9]+\) test /, "", line)
      module = line; sub(/.*\(/, "", module); sub(/\)$/, "", module)
      sub(/ \([^()]*\)$/, "", line)
      name = "Elixir." module "::test " line; where = ""; err = ""; next
    }
    name != "" && where == "" && /^ +test\/.*:[0-9]+$/ { where = $1; next }
    name != "" && err == "" && /^ +\*\* \(/ { err = $0; sub(/^ +/, "", err); err = substr(err, 1, 200) }
    name != "" && err == "" && /^ +Assertion/ { err = $0; sub(/^ +/, "", err) }
    END { if (name != "") print r "\t" name "\t" where "\t" err }'
done | sort -t$'\t' -k2,2 -k1,1 | awk -F'\t' -v rounds="$ROUNDS" '
  { seen[$2] = 1; state[$2, $1] = "failed"; file[$2] = $3; if (!($2 in err) || err[$2] == "") err[$2] = $4 }
  END {
    for (t in seen) {
      printf "%s\t%s", t, file[t]
      for (r = 1; r <= rounds; r++) printf "\t%s", (state[t, r] ? "failed" : "passed")
      printf "\t%s\n", err[t]
    }
  }' | sort > "$OUT/failures.body"
{ printf 'test\tfile'; for r in $(seq "$ROUNDS"); do printf '\tround_%s' "$r"; done; printf '\terror\n'; cat "$OUT/failures.body"; } > "$OUT/project_test_failures.tsv"
rm -f "$OUT/failures.body"
wc -l "$OUT"/project_tests.tsv "$OUT"/project_test_failures.tsv
