#!/usr/bin/env bash
# pool_table.sh: one line per pull request of a list made and gated by run.sh (make, gate), from the controller's
# outputs: the maker's line (make.tsv), the two checks (verify.tsv), the resolver's line (resolve.tsv of the same
# list's `resolve` run) and the gate's row.json. Needs jq.
#   pool_table.sh DATA RESOLVE_TSV > tasks.tsv
# A control column says whether the grader accepted or rejected that patch (the gate needs the unchanged project,
# the early exit and the partial fix rejected, the reference accepted).
# DATA is the list's folder in the controller's data (with out/make.tsv, out/verify.tsv, out/<id>/row.json).
set -euo pipefail
data=${1:?DATA}
resolve=${2:?RESOLVE_TSV}
printf 'repository\tnumber\tid\telixir_otp\tbaseline\tpostgres\tmade\tsource_check\timport\tprepared\tstart_failed_in_body\tstart_counts\treference_counts\tpartial\tcontrol_unchanged\tcontrol_reference\tcontrol_early_exit\tcontrol_partial\tsecond_round\tverdict\tdropped_at\treason\tcommand_files\tleft_out\tprepare_s\tprobe_s\tgate_s\tsecond_s\ttotal_s\n'
tail -n +2 "$data/out/make.tsv" | while IFS=$'\t' read -r repository number id result reason _rest; do
  r=$(awk -F'\t' -v n="$number" '$2 == n {p = $12; sub(/@sha256:.*/, "", p); print $7 "/" $9 "\t" $14 "\t" p; exit}' "$resolve")
  [ -n "$r" ] || r=$'-\t-\t-'
  made=$([ "$result" = made ] && echo made || echo "refused: $reason")
  v=$(awk -F'\t' -v i="$id" '$1 == i {s = $2; m = $3; sub(/ .*/, "", m); print substr(s, 1, 120) "\t" m; exit}' "$data/out/verify.tsv" 2>/dev/null | cut -c1-200)
  [ -n "$v" ] || v=$'-\t-'
  row="$data/out/$id/row.json"
  if [ "$result" = made ] && [ -f "$row" ]; then
    g=$(jq -r '
      def c(x): if x == null then "-" else (x | to_entries | map("\(.key) \(.value)") | join(", ")) end;
      def ctl(x): if x == null then "-" elif x.passed == true then "accepted" else "rejected" end;
      def s(x): if x == null then "-" else ((x / 100 | round) / 10 | tostring) end;
      [ (.prepared // "-"), (.diag_start.failed_in_body // "-"), c(.diag_start.counts), c(.diag_reference.counts),
        ((.partial_control // null) | if . == null then "-" elif .present == true then "present" else (.reason // "-") end),
        ctl(.controls.empty_patch), ctl(.controls.reference_patch), ctl(.controls.early_exit), ctl(.controls.partial_repair),
        (if .second_round == null then "-" elif .second_round.same then "same" else "changed" end),
        .verdict, (.dropped_at // "-"), ((.reason // "-") | tostring),
        ((.preservation // []) | join(" ") | if . == "" then "-" else . end),
        ((.preservation_left_out // []) | map("\(.file) (\(.reason))") | join("; ") | if . == "" then "-" else . end),
        s(.prepare_ms), s(.probe_ms), s(.gate_ms), s(.second_ms), s(.total_ms) ] | @tsv' "$row")
  else
    g=$'-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tnot made\tmake\t'"$reason"$'\t-\t-\t-\t-\t-\t-\t-'
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repository" "$number" "$id" "$r" "$made" "$v" "$g"
done
