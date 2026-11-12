#!/usr/bin/env bash
# compare.sh: one task's check on this machine against the record of its earlier check on another machine. Prints
# one tab-separated line per compared item: item, earlier, now, same (yes/no). Long values are shown by their
# SHA-256 (first 16 hex digits) after the first 60 characters.
# Environment: ROW (the earlier gate's row.json), OLD_CONTROLS (the earlier controller's saved controls,
# data/controls/<id>.json), RESULT (the new check's results/<id>.json), NEW_CONTROLS (the new controller's
# data/controls/<id>.json), BEFORE (the task folder as imported), AFTER (the task folder after the check).
set -euo pipefail
: "${ROW:?}" "${OLD_CONTROLS:?}" "${RESULT:?}" "${NEW_CONTROLS:?}" "${BEFORE:?}" "${AFTER:?}"
short() { if [ ${#1} -gt 60 ]; then printf '%s… sha256:%s' "${1:0:60}" "$(printf '%s' "$1" | sha256sum | cut -c1-16)"; else printf '%s' "$1"; fi; }
line() {
  if [ "$2" = "$3" ]; then s=yes; else s=no; fi
  printf '%s\t%s\t%s\t%s\n' "$1" "$(short "$2")" "$(short "$3")" "$s"
}
printf 'item\tearlier\tnow\tsame\n'
line verdict "$(jq -r .verdict "$ROW")" "$(jq -r .verdict "$RESULT")"
line probe "$(jq -r .probe "$ROW")" "$(jq -r .probe "$RESULT")"
line "hidden tests failing on the unchanged project (count)" "$(jq -r .starting_failures "$ROW")" "$(jq -r .hidden_failing_first "$RESULT")"
line "hidden tests passing with the reference (count)" "$(jq -r .required "$ROW")" "$(jq -r .hidden_passing_after "$RESULT")"
line "existing tests command" "$(jq -r .first_reading "$ROW")" "$(jq -r .preservation "$RESULT")"
line "existing test files left out" "$(jq -c .preservation_left_out "$ROW")" "$(jq -c .preservation_left_out "$RESULT")"
line "partial control" "$(jq -c .partial_control "$ROW")" "$(jq -c .partial_control "$RESULT")"
for k in same changed empty_passed reference_passed; do
  line "second round: $k" "$(jq -c ".second_round.$k" "$ROW")" "$(jq -c ".second_round.$k" "$RESULT")"
done
for k in required starting_failures preservation preservation_left_out; do
  line "case.json grading.$k" "$(jq -c ".grading.$k" "$BEFORE/case.json")" "$(jq -c ".grading.$k" "$AFTER/case.json")"
done
line "case.json partial_control" "$(jq -c .partial_control "$BEFORE/case.json")" "$(jq -c .partial_control "$AFTER/case.json")"
for f in "$BEFORE"/*; do
  n=$(basename "$f")
  line "task file $n (sha256)" "$(sha256sum < "$f" | cut -c1-16)" "$( (sha256sum < "$AFTER/$n" 2>/dev/null || echo missing) | cut -c1-16)"
done
line "saved controls: valid" "$(jq -c .valid "$OLD_CONTROLS")" "$(jq -c .valid "$NEW_CONTROLS")"
for c in reference_patch empty_patch partial_repair early_exit; do
  line "control $c: passed" "$(jq -c ".$c.passed" "$OLD_CONTROLS")" "$(jq -c ".$c.passed" "$NEW_CONTROLS")"
  for part in hidden regression submission; do
    for k in completed passed returncode; do
      line "control $c: $part.$k" "$(jq -c ".$c.$part.$k" "$OLD_CONTROLS")" "$(jq -c ".$c.$part.$k" "$NEW_CONTROLS")"
    done
    line "control $c: $part test states by name" "$(jq -cS ".$c.$part.test_results" "$OLD_CONTROLS")" "$(jq -cS ".$c.$part.test_results" "$NEW_CONTROLS")"
    line "control $c: $part failing tests and phase" "$(jq -cS ".$c.$part.failure_phases" "$OLD_CONTROLS")" "$(jq -cS ".$c.$part.failure_phases" "$NEW_CONTROLS")"
  done
done
for k in case grader runtime; do
  line "controls identity.$k" "$(jq -cS ".identity.$k" "$OLD_CONTROLS")" "$(jq -cS ".identity.$k" "$NEW_CONTROLS")"
done
