#!/usr/bin/env bash
# table.sh: the job's tables from all.sh's rows (OUT/rows.tsv) and one.sh's folders, on the data-mining machine.
#   table.sh tasks    one line per try: the merge date (SCREEN_TSV), the Elixir/OTP pair and the task kind (the made
#                     folder in TASKDIR), the columns of rows.tsv without the job id, the engine's
#                     step times in seconds (import check, source, prepare, probe, controls; the steps after the
#                     probe added to controls), the bytes of this job's own images added during the try (MINE: the ids
#                     of the images that carry this job's label; their sizes overlap, as images share layers), the
#                     machine's build cache change and free bytes used (every job's, not this one's alone), the
#                     licence and hold-out results (SCANS/<id>/) and whose cause a drop is (CAUSES: id, cause)
#   table.sh counts   per verdict, step and reason, the pull requests counted by their last try
#   table.sh images   every image the job added, by name and bytes, with the try that added it
# A listed pull request with no row (NUMBERS, all.sh's list) gets one line "not run", with the reason HELD_REASON when
# its id is in HOLD (OUT/hold.txt).
# Environment: OUT (all.sh's output folder), NUMBERS (one number per line), PREFIX (sanbase2), TASKDIR (the
# maker's task folders), SCREEN_TSV (the screen table), HELD_REASON, MINE, SCANS, CAUSES (both optional). Needs jq.
set -euo pipefail
: "${OUT:?}"
R=$OUT/rows.tsv
HOLD=${HOLD:-$OUT/hold.txt}
HELD_REASON=${HELD_REASON:-held}
: "${NUMBERS:?}" "${TASKDIR:?}" "${SCREEN_TSV:?}"
PREFIX=${PREFIX:-sanbase2}
# the merge date of a pull request, from the screen table
merged() { awk -F'\t' -v n="$1" '$1 == n {print substr($2, 1, 10); f = 1} END {if (!f) print "-"}' "$SCREEN_TSV"; }
# the Elixir/OTP pair the maker resolved, and the task kind, from the made folder; "-" when there is none
pair() { jq -r '"\(.toolchain.elixir.value // "-")/\(.toolchain.otp.value // "-")"' "$TASKDIR/$1/provenance.json" 2>/dev/null || echo -; }
kind() { jq -r '.task_kind // "-"' "$TASKDIR/$1/case.json" 2>/dev/null || echo -; }
# this job's own images among those a try added: their bytes summed
own_bytes() { awk -F'\t' 'NR == FNR {m[$1] = 1; next} ($1 in m) {s += $3} END {print s + 0}' "${MINE:-/dev/null}" "$1" 2>/dev/null || echo -; }
scan_result() { awk -F'\t' -v c="$2" 'NR == 2 {print (c == "last" ? $NF : $c)}' "${SCANS:-/nonexistent}/$1/$3" 2>/dev/null | grep . || echo -; }
# whose cause a drop is: CAUSES first (a person's reading); else, for the reasons that always name the pull request
# (docs/dataset_rules.md, sections 3 and 4), "pull_request"; else "-"
# from the check's result: hidden tests failing first and passing after, the partial fix, existing test files kept
checked_counts() { jq -r '[(.hidden_failing_first // "-"), (.hidden_passing_after // "-"), (if .partial_control == null then "-" elif .partial_control.present then "present" else (.partial_control.reason // "absent") end), (.preservation_files // "-")] | map(tostring) | join("\t")' "$1" 2>/dev/null || printf -- '-\t-\t-\t-'; }
cause() {
  local c
  c=$(awk -F'\t' -v i="$1" '$1 == i {print $2; exit}' "${CAUSES:-/dev/null}")
  if [ -n "$c" ]; then echo "$c"; return; fi
  case $2 in
  no_existing_tests | no_test_part | no_test_names | no_code_part | start_run_did_not_finish | no_starting_failure | skipped_test) echo pull_request ;;
  *) echo - ;;
  esac
}
# the listed ids that have no row: id, then the reason
not_run() {
  while read -r n; do
    id=$PREFIX-pr-$n
    awk -F'\t' -v i="$id" 'NR > 1 && $4 == i {f = 1} END {exit !f}' "$R" && continue
    why="not reached"
    if [ -f "$HOLD" ] && grep -qx "$id" "$HOLD"; then why=$HELD_REASON; fi
    printf '%s\t%s\t%s\n' "$n" "$id" "$why"
  done < "$NUMBERS"
}
what=${1:?tasks|counts|images}
# the last try of each pull request
last() { awk -F'\t' 'NR > 1 {row[$4] = $0; if (!($4 in seen)) {seen[$4] = 1; order[++n] = $4}} END {for (i = 1; i <= n; i++) print row[order[i]]}' "$R"; }
case $what in
tasks)
  printf 'try\tnumber\tid\tmerged\telixir_otp\ttask_kind\tfolder\tverdict\tdropped_at\treason\tmake_s\timport_s\tcheck_s\texport_s\tengine_import_check_s\tengine_source_s\tengine_prepare_s\tengine_probe_s\tengine_controls_s\tengine_total_s\tload_start\tload_end\tload_max_check\tsettled\town_images_bytes\tmachine_build_cache_change_bytes\tmachine_free_bytes_used\tlicence\tholdout\tcause\thidden_failing_first\thidden_passing_after\tpartial_fix\texisting_test_files\tstart\tend\n'
  tail -n +2 "$R" | while IFS=$'\t' read -r try _repo number id folder make_s import_s check_s export_s verdict dropped_at reason steps load_start load_end load_max settled _images images_bytes cache_b cache_a fb fa _job start end _detail; do
    s() { # the sum of the named steps' ms, in seconds to one decimal; "-" when none is present
      printf '%s\n' "$steps" | tr ' ' '\n' | awk -F= -v names="$1" 'BEGIN {n = split(names, k, ","); for (i = 1; i <= n; i++) want[k[i]] = 1}
        ($1 in want) {t += $2; f = 1} END {if (f) printf "%.1f", t / 1000; else printf "-"}'
    }
    printf '%s\t' "$try" "$number" "$id" "$(merged "$number")" "$(pair "$id")" "$(kind "$id")" "$folder" "$verdict" "$dropped_at" "$reason" "$make_s" "$import_s" "$check_s" "$export_s" \
      "$(s import_check_ms)" "$(s source_ms)" "$(s prepare_ms)" "$(s probe_ms)" \
      "$(s controls_ms,import_check_after_probe_ms,source_after_probe_ms,prepare_after_probe_ms)" "$(s total_ms)" \
      "$load_start" "$load_end" "$load_max" "$settled" "$(own_bytes "$OUT/$id/$try/images_added.tsv")" "$((cache_a - cache_b))" "$((fb - fa))" \
      "$(scan_result "$id" 8 licence.tasks.tsv)" "$(scan_result "$id" last holdout.tasks.tsv)" "$(cause "$id" "$reason")" "$(checked_counts "$OUT/$id/$try/result.json")" "$start"
    printf '%s\n' "$end"
  done
  not_run | while IFS=$'\t' read -r number id why; do
    printf -- '-\t%s\t%s\t%s\t-\t-\t-\tnot run\t-\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\n' "$number" "$id" "$(merged "$number")" "$why"
  done
  ;;
counts)
  printf 'pull_requests\tverdict\tdropped_at\treason\n'
  { last | awk -F'\t' '{print $10 "\t" $11 "\t" $12}'; not_run | awk -F'\t' '{print "not run\t-\t" $3}'; } | sort | uniq -c | sort -rn | awk '{c = $1; sub(/^ *[0-9]+ /, ""); print c "\t" $0}'
  ;;
images)
  printf 'try\tid\timage_id\tnames\tbytes\n'
  tail -n +2 "$R" | while IFS=$'\t' read -r try _repo _number id _rest; do
    f=$OUT/$id/$try/images_added.tsv
    [ -s "$f" ] || continue
    awk -F'\t' -v t="$try" -v i="$id" '{print t "\t" i "\t" $1 "\t" $2 "\t" $3}' "$f"
  done
  ;;
*) echo "unknown table $what"; exit 2 ;;
esac
