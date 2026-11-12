#!/usr/bin/env bash
# table.sh: the per-pull-request table of job P5 (tasks.tsv) from the maker's result lines (make.tsv, verify.tsv)
# and the gate's rows (<id>/row.json), with jq. Environment: OUT (the run's out/ folder in the controller's data), R1
# (the first run's tasks.tsv, for its verdict beside this one).
set -euo pipefail
: "${OUT:?}" "${R1:?}"
r1() { awk -F'\t' -v n="$1" '$1==n { print $18 ($19 != "-" ? " at " $19 ": " $20 : "") }' "$R1"; }
run() { # "completed body/setup" of a hidden run summary, or "not finished"
  jq -r --arg k "$2" '.[$k] | if . == null then "-" elif .completed then
    "finished: \(.counts.failed // 0) failed (\(.failed_in_body) in body, \(.failed_in_setup) in set-up), \(.counts.passed // 0) passed"
    else "did not finish" end' "$1"
}
ctl() { # one control's outcome
  jq -r --arg k "$2" '.controls[$k] | if . == null then "-" elif .passed then "passed" else
    "rejected (hidden \(if .hidden.completed then "finished, \(.hidden.failed_in_body) fail in body" else "did not finish" end))" end' "$1" 2>/dev/null || echo -
}
printf 'number\tid\tverdict_r1\tmade\tsource_check\timport\tprepared\tstart_run\treference_run\trequired\tstarting_failures\tpartial\tcontrol_unchanged\tcontrol_reference\tcontrol_early_exit\tcontrol_partial\tsecond_round\texisting_tests_changed\tverdict\tdropped_at\treason\tmake_s\tprepare_s\tprobe_s\tgate_s\tsecond_s\ttotal_s\tdisk_free_change_gb\texisting_first_reading\texisting_kept\texisting_left_out\tsecond_round_strict\n'
tail -n +2 "$OUT/make.tsv" | while IFS=$'\t' read -r _repo number id result reason _rest; do
  if [ "$result" != made ]; then
    printf '%s\t-\t%s\trefused: %s\n' "$number" "$(r1 "$number")" "$reason"; continue
  fi
  make_s=$(awk -F'\t' -v n="$number" '$1==n{printf "%.1f", $2/1000}' "$OUT/make_times.tsv")
  v=$(awk -F'\t' -v i="$id" '$1==i' "$OUT/verify.tsv")
  sc=$(cut -f2 <<<"$v"); im=$(cut -f3 <<<"$v" | cut -d' ' -f1)
  row=$OUT/$id/row.json
  if [ ! -f "$row" ]; then
    printf '%s\t%s\t%s\tmade\t%s\t%s\tnot run\n' "$number" "$id" "$(r1 "$number")" "$sc" "$im"; continue
  fi
  jq -r --arg n "$number" --arg r1 "$(r1 "$number")" --arg mk "$make_s" --arg sc "$sc" --arg im "$im" \
    --arg sr "$(run "$row" diag_start)" --arg rr "$(run "$row" diag_reference)" \
    --arg c1 "$(ctl "$row" empty_patch)" --arg c2 "$(ctl "$row" reference_patch)" \
    --arg c3 "$(ctl "$row" early_exit)" --arg c4 "$(ctl "$row" partial_repair)" '
    def s(x): if x == null then "-" else (x / 1000 * 10 | round / 10 | tostring) end;
    [$n, .id, $r1, "made", $sc, $im, (if .prepared then "yes" else "no" end), $sr, $rr,
     (.required // "-" | tostring), (.starting_failures // "-" | tostring),
     (if .partial_control == null then "-" elif .partial_control.present then "found" else "none: \(.partial_control.reason)" end),
     $c1, $c2, $c3, $c4,
     (if .second_round == null then "-" elif .second_round.same then "same" else "differs: \(.second_round.changed | map(select(contains("/hidden: "))) | length) hidden" end),
     (if .second_round == null then "-" else (.second_round.existing_changed | join("; ")) | if . == "" then "none" else . end end),
     .verdict, (.dropped_at // "-"), (.reason // "-"),
     $mk, s(.prepare_ms), s(.probe_ms), s(.gate_ms), s(.second_ms), s(.total_ms),
     (if .free_before and .free_after then ((.free_before - .free_after) / 1e9 * 100 | round / 100 | tostring) else "-" end),
     ((.first_reading // "-") | sub("^mix test ?"; "") | gsub(" "; "; ")),
     (if .preservation == null then "-" else (.preservation | join("; ")) end),
     (if .preservation_left_out == null then "-" elif .preservation_left_out == [] then "none" else (.preservation_left_out | map("\(.file) (\(.reason))") | join("; ")) end),
     (if .second_round == null then "-" elif .second_round.same_all then "same" else "differs" end)
    ] | @tsv' "$row"
done
