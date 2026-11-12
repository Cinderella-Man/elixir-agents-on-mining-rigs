#!/usr/bin/env bash
# cases_table.sh: the public tables of the job's tries, on the data-mining machine, from all.sh's rows (OUT/rows.tsv),
# one.sh's folders (OUT/<id>/<try>/) and Docker's disk-use API.
#   cases_table.sh images  every image that carries JOB_LABEL: id (12 characters), created, bytes, shared bytes, unique
#                          bytes (bytes minus shared), its tags; written to OUT/images_df.tsv and printed
#   cases_table.sh cases   one line per try of the ids in IDS (one id per line; default: every try in rows.tsv), in the
#                          columns of cases_mbta_screens.tsv: the order in NUMBERS, the merge date (SCREEN_TSV), the
#                          Elixir/OTP pair and the task kind (the made folder in TASKDIR), the verdict, whose cause and
#                          why (NOTES: id, try, whose, why; "-" when the id has no line), the hidden and existing test
#                          counts of the engine's result (a drop's left-out file from its detail when the list is empty),
#                          the wall and engine times (controls: the engine's controls_ms alone), the load, the unique bytes of the
#                          images the try added (OUT/images_df.tsv) and the try's start and end
#   cases_table.sh merge   an earlier public table (BASE) and the `cases` output (NEW) into one table (see the step)
# Environment: OUT (all.sh's output folder), JOB_LABEL (images), NUMBERS, TASKDIR, SCREEN_TSV, NOTES, IDS, PREFIX
# (screens); for merge BASE, NEW, WINDOW, NOT_RUN_REASON, NOT_RUN_WHY. Needs jq and curl.
set -euo pipefail
: "${OUT:?}"
PREFIX=${PREFIX:-screens}
what=${1:?images|cases}
case $what in
images)
  : "${JOB_LABEL:?}"
  key=${JOB_LABEL%%=*} val=${JOB_LABEL#*=}
  curl -s --unix-socket /var/run/docker.sock 'http://localhost/system/df?type=image' |
    jq -r --arg k "$key" --arg v "$val" '.Images[] | select((.Labels // {})[$k] == $v)
      | [(.Id | sub("^sha256:"; "") | .[0:12]), (.Created | todate), .Size, .SharedSize, (.Size - .SharedSize),
         ((.RepoTags // []) | join(" "))] | @tsv' |
    sort -t$'\t' -k2,2 | { printf 'image_id\tcreated\tbytes\tshared_bytes\tunique_bytes\tnames\n'; cat; } > "$OUT/images_df.tsv"
  cat "$OUT/images_df.tsv"
  ;;
cases)
  : "${NUMBERS:?}" "${TASKDIR:?}" "${SCREEN_TSV:?}"
  R=$OUT/rows.tsv
  NOTES=${NOTES:-/dev/null}
  IMG=$OUT/images_df.tsv
  order() { awk -v n="$1" '$1 == n {print NR; f = 1} END {if (!f) print "-"}' "$NUMBERS"; }
  merged() { awk -F'\t' -v n="$1" '$1 == n {print substr($2, 1, 10); f = 1} END {if (!f) print "-"}' "$SCREEN_TSV"; }
  pair() { jq -r '"\(.toolchain.elixir.value // "-")/\(.toolchain.otp.value // "-")"' "$TASKDIR/$1/provenance.json" 2>/dev/null || echo -; }
  kind() { jq -r '.task_kind // "-"' "$TASKDIR/$1/case.json" 2>/dev/null || echo -; }
  note() { awk -F'\t' -v i="$1" -v t="$2" '$1 == i && $2 == t {print $3 "\t" $4; f = 1} END {if (!f) print "-\t-"}' "$NOTES"; }
  # the engine's result: hidden failing first, hidden passing after, the partial-fix control, existing files, left out
  result() {
    jq -r '(.detail // "" | tostring) as $d |
      [(.hidden_failing_first // "-"), (.hidden_passing_after // "-"),
      (if .verdict != "checked" then "-" elif .partial_control.present then "present"
       else "none (\(.partial_control.reason // "-"))" end),
      (.preservation_files // "-"),
      ((.preservation_left_out // []) | map("\(.file):\(.reason)") | join("; ")
       | if . != "" then . elif ($d | test("^test/[^ ]+: [a-z_]+$")) then ($d | sub(": "; ":")) else "-" end)]
      | map(tostring) | @tsv' "$1" 2>/dev/null || printf -- '-\t-\t-\t-\t-\n'
  }
  # the unique bytes of this job's images that a try added (images_added.tsv lists every image new on the machine,
  # other jobs' too; only ids in images_df.tsv, which holds JOB_LABEL's images, count)
  built() {
    [ -s "$1" ] && [ -s "$IMG" ] || { echo 0; return; }
    awk -F'\t' 'NR == FNR {if (FNR > 1) u[$1] = $5; next}
      {i = substr($1, 8, 12); s += (i in u) ? u[i] : 0} END {print s + 0}' "$IMG" "$1"
  }
  if [ -n "${IDS:-}" ]; then want=$(cat "$IDS"); else want=$(awk -F'\t' 'NR > 1 {print $4}' "$R" | sort -u); fi
  printf 'order\tnumber\tid\tmerged\telixir_otp\ttask_kind\ttry\tverdict\tdropped_at\treason\twhose\twhy\thidden_failing_first\thidden_passing_after\tpartial_fix\texisting_test_files\texisting_left_out\tmake_s\timport_s\tcheck_s\texport_s\tengine_prepare_s\tengine_probe_s\tengine_controls_s\tengine_total_s\tload_start\tload_end\tload_max_check\timage_bytes_built\tstart\tend\n'
  tail -n +2 "$R" | while IFS=$'\t' read -r try _repo number id _folder make_s import_s check_s export_s verdict dropped_at reason steps load_start load_end load_max _settled _images _ib _cb _ca _fb _fa _job start end _detail; do
    printf '%s\n' "$want" | grep -qx "$id" || continue
    s() { # the sum of the named steps' ms, in seconds to one decimal; "-" when none is present
      printf '%s\n' "$steps" | tr ' ' '\n' | awk -F= -v names="$1" 'BEGIN {n = split(names, k, ","); for (i = 1; i <= n; i++) want[k[i]] = 1}
        ($1 in want) {t += $2; f = 1} END {if (f) printf "%.1f", t / 1000; else printf "-"}'
    }
    d=$OUT/$id/$try
    printf '%s\t' "$(order "$number")" "$number" "$id" "$(merged "$number")" "$(pair "$id")" "$(kind "$id")" "$try" \
      "$verdict" "$dropped_at" "$reason" "$(note "$id" "$try")" "$(result "$d/result.json")" \
      "$make_s" "$import_s" "$check_s" "$export_s" "$(s prepare_ms)" "$(s probe_ms)" \
      "$(s controls_ms)" "$(s total_ms)" \
      "$load_start" "$load_end" "$load_max" "$(built "$d/images_added.tsv")" "$start"
    printf '%s\n' "$end"
  done
  ;;
merge)
  # BASE (an earlier version of the public table) and NEW (this script's `cases` output) into one table: NEW's rows,
  # BASE's rows whose id and try NEW lacks (its "not run" rows dropped), and a "not run" row (reason NOT_RUN_REASON,
  # why NOT_RUN_WHY) for each number of WINDOW (one per line) with no row; sorted by order, then try (A and S, the
  # earlier job's lettered tries, before 1 and 2)
  : "${BASE:?}" "${NEW:?}" "${WINDOW:?}" "${NUMBERS:?}" "${TASKDIR:?}" "${SCREEN_TSV:?}"
  NOT_RUN_REASON=${NOT_RUN_REASON:-not_reached} NOT_RUN_WHY=${NOT_RUN_WHY:--}
  order() { awk -v n="$1" '$1 == n {print NR; f = 1} END {if (!f) print "-"}' "$NUMBERS"; }
  merged() { awk -F'\t' -v n="$1" '$1 == n {print substr($2, 1, 10); f = 1} END {if (!f) print "-"}' "$SCREEN_TSV"; }
  pair() { jq -r '"\(.toolchain.elixir.value // "-")/\(.toolchain.otp.value // "-")"' "$TASKDIR/$1/provenance.json" 2>/dev/null || echo -; }
  head -1 "$NEW"
  {
    tail -n +2 "$NEW"
    awk -F'\t' 'NR == FNR {if (FNR > 1) seen[$3 "\t" $7] = 1; next} FNR > 1 && $8 != "not run" && !(($3 "\t" $7) in seen)' "$NEW" "$BASE"
    while read -r n; do
      [ -n "$n" ] || continue
      id=$PREFIX-pr-$n
      awk -F'\t' -v i="$id" 'FNR > 1 && $3 == i && $8 != "not run" {f = 1} END {exit !f}' "$NEW" "$BASE" && continue
      printf '%s\t%s\t%s\t%s\t%s\t-\t-\tnot run\t-\t%s\t-\t%s' "$(order "$n")" "$n" "$id" "$(merged "$n")" "$(pair "$id")" "$NOT_RUN_REASON" "$NOT_RUN_WHY"
      printf '\t-%.0s' $(seq 19); printf '\n'
    done < "$WINDOW"
  } | awk -F'\t' -v OFS='\t' '{r = ($7 == "A" || $7 == "S") ? 0 : ($7 == "-" ? 9 : $7); print $1 + 0, r, $0}' |
    sort -t$'\t' -k1,1n -k2,2n -s | cut -f3-
  ;;
*) echo "unknown table $what"; exit 2 ;;
esac
