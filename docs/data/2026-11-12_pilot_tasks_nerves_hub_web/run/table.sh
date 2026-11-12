#!/usr/bin/env bash
# table.sh: one line per pull request of numbers.txt, in the mass run's columns (docs/data/2026-11-12_pilot_tasks_all),
# from the maker's make.tsv and verify.tsv, the pool's records and the factory's check results, plus the screen's
# AI-tool mark and the ClickHouse image. The factory's check records the time of its own steps (source, prepare, the
# checks after the probe) and the total, not the probe's and the controls' apart: probe_s, gate_s and second_s are
# "-", and probe_gate_s is the total less the recorded steps. start_counts and reference_counts come from the
# check's counts of hidden tests (failing first, passing after). The four control columns of a checked task are the
# outcomes a checked verdict requires (README section 4); for a task dropped at the controls the reason names the
# first control that failed.
# Environment: D (the list's folder in the controller's data, on the host), DATA (the controller's data folder),
# SCREEN (the screen table), REPOSITORY.
set -euo pipefail
: "${D:?}" "${DATA:?}" "${SCREEN:?}"
REPOSITORY=${REPOSITORY:-https://github.com/nerves-hub/nerves_hub_web}
printf 'repository\tnumber\tid\telixir_otp\tbaseline\tpostgres\tmade\tsource_check\timport\tprepared\tstart_failed_in_body\tstart_counts\treference_counts\tpartial\tcontrol_unchanged\tcontrol_reference\tcontrol_early_exit\tcontrol_partial\tsecond_round\tverdict\tdropped_at\treason\tcommand_files\tleft_out\tprepare_s\tprobe_s\tgate_s\tsecond_s\ttotal_s\tprobe_gate_s\tclickhouse\tai_tool\tjob\n'
col() { awk -F'\t' -v c="$1" 'NR==1 {for (i = 1; i <= NF; i++) if ($i == c) k = i; next} {print (k ? $k : "")}'; }
for n in $(tr -s ' ,' '\n\n' < "$D/numbers.txt" | grep .); do
  row=$(awk -F'\t' -v n="$n" 'NR==1 {h = $0; next} $2 == n {print h; print; exit}' "$D/out/make.tsv")
  get() { printf '%s\n' "$row" | col "$1"; }
  result=$(get result); reason=$(get reason); id=$(get id); [ -n "$id" ] || id=-
  ai=$(awk -F'\t' -v n="$n" 'NR==1 {for (i = 1; i <= NF; i++) if ($i == "ai_tool") k = i; next} $1 == n {print $k}' "$SCREEN")
  case=$D/tasks/$id/case.json
  if [ -f "$case" ]; then
    eo=$(jq -r '.runtime.image | capture("elixir:(?<e>[0-9.]+)-erlang-(?<o>[0-9.]+)") | "\(.e)/\(.o)"' "$case")
    bl=$(jq -r '.baseline.commands | join(" && ")' "$case")
    pg=$(jq -r '.services.postgres.image // "-" | sub("@.*"; "")' "$case")
    ch=$(jq -r '.services.clickhouse.image // "-" | sub("@.*"; "")' "$case")
  else eo=-; bl=-; pg=-; ch=-; fi
  if [ "$result" != made ]; then
    printf '%s\t%s\t-\t%s\t%s\t%s\trefused: %s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tnot made\tmake\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t%s\t%s\t-\n' \
      "$REPOSITORY" "$n" "$eo" "$bl" "$pg" "$reason" "$reason" "$ch" "$ai"
    continue
  fi
  v=$(awk -F'\t' -v id="$id" '$1 == id {print $2 "\t" $3; exit}' "$D/out/verify.tsv"); sc=${v%%$'\t'*}; im=${v#*$'\t'}
  job=$(awk -F'\t' -v id="$id" '$1 == id {j = $2} END {print j}' "$D/pool/jobs.tsv" 2> /dev/null || true)
  verdict=$(awk -F'\t' -v id="$id" '$1 == id {v = $2} END {print v}' "$D/pool/verdicts.tsv" 2> /dev/null || true)
  r=$DATA/factory/jobs/$job/results/$id.json
  if [ -z "$job" ] || [ ! -f "$r" ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\tmade\t%s\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t%s\t-\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t%s\t%s\t-\n' \
      "$REPOSITORY" "$n" "$id" "$eo" "$bl" "$pg" "$sc" "$im" "${verdict:-not_tried}" \
      "$(awk -F'\t' -v id="$id" '$1 == id {x = $4} END {print (x ? x : "-")}' "$D/pool/verdicts.tsv" 2> /dev/null)" "$ch" "$ai"
    continue
  fi
  jq -r --arg repo "$REPOSITORY" --arg n "$n" --arg eo "$eo" --arg bl "$bl" --arg pg "$pg" --arg ch "$ch" \
    --arg ai "$ai" --arg sc "$sc" --arg im "$im" '
    def s(ms): if ms == null then "-" else ((ms / 100 | round) / 10 | tostring) end;
    def steps: [.source_ms, .prepare_ms, .import_check_ms, .import_check_after_probe_ms, .source_after_probe_ms,
                .prepare_after_probe_ms] | map(. // 0) | add;
    (.verdict == "checked") as $ok |
    [$repo, $n, .id, $eo, $bl, $pg, "made", $sc, $im,
     (if .prepare_ms != null then "true" elif .dropped_at == "prepare" then "false" else "-" end),
     (.hidden_failing_first // "-" | tostring),
     (if .hidden_failing_first != null then "failed \(.hidden_failing_first)" else "-" end),
     (if .hidden_passing_after != null then "passed \(.hidden_passing_after)" else "-" end),
     (if .partial_control == null then "-" elif .partial_control.present then "present"
      else (.partial_control.reason // "absent") end),
     (if $ok then "rejected" else "-" end), (if $ok then "accepted" else "-" end),
     (if $ok then "rejected" else "-" end),
     (if $ok and .partial_control.present then "rejected" else "-" end),
     (if .second_round == null then "-" elif .second_round.same then "same" else "changed" end),
     .verdict, (.dropped_at // "-"), (.reason // "-"),
     (.preservation // "-" | sub("^mix test ?"; "") | if . == "" then "-" else . end),
     ((.preservation_left_out // []) | map("\(.file):\(.reason)") | join(" ") | if . == "" then "-" else . end),
     s(.prepare_ms), "-", "-", "-", s(.total_ms),
     (if .total_ms != null then s(.total_ms - steps) else "-" end),
     $ch, $ai, .job] | @tsv' "$r"
done
