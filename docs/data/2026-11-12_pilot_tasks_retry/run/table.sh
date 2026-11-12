#!/usr/bin/env bash
# table.sh: one line per pull request of a check job, in the columns of the mass run's task tables
# (docs/data/2026-11-12_pilot_tasks_all/run/pool_table.sh), from the factory's own files. Needs jq.
#   table.sh DATA JOB SUB... > tasks.tsv
# DATA is the controller's data folder on the host; JOB the check job's id; each SUB a list folder in DATA made by
# retry.sh (out/make.tsv, out/verify.tsv). The tasks are read from DATA/factory/jobs/JOB/results/<id>.json, the
# manifests from the job's probed copy (work/<id>/case.json) or the task folder TASKS (default DATA/../tasks), and the
# controls from DATA/controls/<id>.json when the controls got as far as saving them.
# Where the columns come from, beside the mass run's gate script:
#   start_failed_in_body   the hidden tests the probe found failing in their body before the fix (the manifest's
#                          starting_failures); the factory runs no separate diagnostic runs
#   start_counts, reference_counts   the hidden tests' states in the controls (the unchanged project, the reference)
#   prepare_s              import check, source check and preparation
#   probe_s, gate_s        probe_ms and controls_ms when the result has them (from this job's fix on); otherwise from
#                          the job's progress.log, to the second: the probe from "Observing the hidden tests" to
#                          "Checking broken, reference" (or to the verdict when the probe dropped it), the controls
#                          from there to the verdict; gate_s includes the second round
#   second_s               "-": the second round runs inside the controls
set -euo pipefail
data=${1:?DATA}
job=${2:?JOB}
shift 2
tasks=${TASKS:-$data/../tasks}
J=$data/factory/jobs/$job
printf 'repository\tnumber\tid\telixir_otp\tbaseline\tpostgres\tmade\tsource_check\timport\tprepared\tstart_failed_in_body\tstart_counts\treference_counts\tpartial\tcontrol_unchanged\tcontrol_reference\tcontrol_early_exit\tcontrol_partial\tsecond_round\tverdict\tdropped_at\treason\tcommand_files\tleft_out\tprepare_s\tprobe_s\tgate_s\tsecond_s\ttotal_s\n'
secs() { date -d "$1" +%s; }
for sub in "$@"; do
  tail -n +2 "$data/$sub/out/make.tsv" | while IFS=$'\t' read -r repository number id result reason _r; do
    toolchain=$(awk -F'\t' -v n="$number" '$2 == n {print $17; exit}' "$data/$sub/out/make.tsv")
    made=$([ "$result" = made ] && echo made || echo "refused: $reason")
    v=$(awk -F'\t' -v i="$id" '$1 == i {m = $3; sub(/ .*/, "", m); print $2 "\t" m; exit}' "$data/$sub/out/verify.tsv")
    [ -n "$v" ] || v=$'-\t-'
    res=$J/results/$id.json
    if [ ! -f "$res" ]; then
      if [ "$result" = made ]; then w=$'not checked\t-\t-'; else w="not made\tmake\t$reason"; fi
      printf "%s\t%s\t%s\t%s\t-\t-\t%s\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t%b\t-\t-\t-\t-\t-\t-\t-\n" "$repository" "$number" "$id" "$toolchain" "$made" "$v" "$w"
      continue
    fi
    manifest=$J/work/$id/case.json
    [ -f "$manifest" ] || manifest=$tasks/$id/case.json
    env=$(jq -r '[(.baseline.commands // [] | join(" && ")), ((.services.postgres.image // "-") | sub("@sha256:.*"; ""))] | @tsv' "$manifest")
    controls=$data/controls/$id.json
    [ -f "$controls" ] || controls=/dev/null
    # times from the progress log, to the second, for a result without probe_ms and controls_ms
    log=$J/progress.log
    t_probe=$(grep -m1 "^[^ ]* $id: Observing the hidden tests of " "$log" | cut -d' ' -f1 || true)
    t_ctl=$(grep -m1 "^[^ ]* $id: Checking broken, reference" "$log" | cut -d' ' -f1 || true)
    t_end=$(jq -r '.finished_at' "$res")
    probe_s=-; gate_s=-
    if [ -n "$t_probe" ]; then
      if [ -n "$t_ctl" ]; then
        probe_s=$(( $(secs "$t_ctl") - $(secs "$t_probe") ))
        gate_s=$(( $(secs "$t_end") - $(secs "$t_ctl") ))
      else
        probe_s=$(( $(secs "$t_end") - $(secs "$t_probe") ))
      fi
    fi
    g=$(jq -r --slurpfile cs "$controls" --arg probe_s "$probe_s" --arg gate_s "$gate_s" '
      $cs[0] as $c |
      def counts(x): if x == null then "-" else (x.test_results // {} | [.[]] | group_by(.) | map("\(.[0]) \(length)") | join(", ") | if . == "" then "-" else . end) end;
      def ctl(x): if x == null then "-" elif x.passed == true then "accepted" else "rejected" end;
      def s(x): if x == null then "-" else ((x / 100 | round) / 10 | tostring) end;
      def sum(xs): if (xs | map(select(. != null)) | length) == 0 then null else (xs | map(. // 0) | add) end;
      [ (if .dropped_at == "import_check" or .dropped_at == "source" then "-" elif .dropped_at == "prepare" then "false" else "true" end),
        (.hidden_failing_first // "-"),
        counts($c.empty_patch.hidden), counts($c.reference_patch.hidden),
        ((.partial_control // null) | if . == null then "-" elif .present == true then "present" else (.reason // "-") end),
        ctl($c.empty_patch), ctl($c.reference_patch), ctl($c.early_exit), ctl($c.partial_repair),
        (if .second_round == null then "-" elif .second_round.same then "same" else "changed" end),
        .verdict, (.dropped_at // "-"), ((.reason // "-") | tostring),
        ((.preservation // "") | sub("^mix test ?"; "") | if . == "" then "-" else . end),
        ((.preservation_left_out // []) | map("\(.file) (\(.reason))") | join("; ") | if . == "" then "-" else . end),
        s(sum([.import_check_ms, .source_ms, .prepare_ms])),
        (if .probe_ms then s(.probe_ms) else $probe_s end),
        (if .controls_ms then s(sum([.import_check_after_probe_ms, .source_after_probe_ms, .prepare_after_probe_ms, .controls_ms])) else $gate_s end),
        "-", s(.total_ms) ] | @tsv' "$res")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repository" "$number" "$id" "$toolchain" "$env" "$made" "$v" "$g"
  done
done
