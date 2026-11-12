#!/usr/bin/env bash
# final_tables.sh: the job's public tables, on the data-mining machine, from table.sh's output and the screening.
#   cases     one line per try: table.sh's tasks table (the engine's step times, the load), whose cause each try's
#             drop is (WHOSE: id, try, whose, why; written by a person from each drop's detail), the job's own images
#             added during the try (OWN: own_images.sh tries, by the engine's job label) and the machine-wide disk
#             change
#   ready     every screened candidate of the project (CLASSES, the screening's classes table): its Elixir/OTP as the
#             resolver reads it after the newer pairs (RESOLVE: resolve_after.tsv), what else it needs, and where it
#             stands after this job (TASKS: the cases table)
# Environment: TASKS (table.sh tasks), OWN, WHOSE, CLASSES, RESOLVE, REPO (ambry-app/ambry).
set -euo pipefail
what=${1:?cases|ready}
REPO=${REPO:-ambry-app/ambry}
case $what in
cases)
  : "${TASKS:?}" "${OWN:?}" "${WHOSE:?}"
  awk -F'\t' -v OFS='\t' '
    FILENAME == ARGV[1] {if (FNR > 1) {own[$1 "\t" $2] = $3 "\t" $5}; next}
    FILENAME == ARGV[2] {if (FNR > 1) {whose[$1 "\t" $2] = $3}; next}
    FNR == 1 {print "number", "id", "try", "merged", "elixir_otp", "task_kind", "verdict", "dropped_at", "reason", "whose",
      "make_s", "check_s", "export_s", "engine_prepare_s", "engine_probe_s", "engine_controls_s", "engine_total_s",
      "load_start", "load_end", "load_max_check", "settled", "own_images_added", "own_images_unique_bytes",
      "machine_disk_used_bytes", "start", "end"; next}
    {k = $3 "\t" $1
     print $2, $3, $1, $4, $5, $6, $8, $9, $10, (k in whose) ? whose[k] : "-", $11, $13, $14, $17, $18, $19, $20, $21,
      $22, $23, $24, (k in own) ? own[k] : "-\t-", $27, $28, $29}' "$OWN" "$WHOSE" "$TASKS"
  ;;
ready)
  : "${CLASSES:?}" "${RESOLVE:?}" "${TASKS:?}"
  awk -F'\t' -v OFS='\t' -v repo="$REPO" '
    FILENAME == ARGV[1] {if ($1 == repo) img[$2] = $8; next}
    FILENAME == ARGV[2] {if (FNR > 1) done[$2] = $8 (($8 == "checked") ? "" : ": " $10); next}
    FNR == 1 {print "number", "merged", "elixir_otp", "image_now", "needs_else", "status"; next}
    {
      n = $2; im = (n in img) ? img[n] : "-"; other = $9
      if (n in done) st = "tried: " done[n]
      else if ($14 == "yes" || ($5 != "" && $5 !~ /^1\.(1[89]|[2-9][0-9])/)) st = "left out: elixir_before_1.18"
      else if (im ~ /\/27\.2(\.|$)/) st = "left out: " im " (OTP 27.2 is never built)"
      else if (im !~ /^ok:/) st = "waits: " im
      else if (other != "-") st = "waits for the owner: " other
      else st = "ready, not tried"
      print n, substr($3, 1, 10), $5 "/" $6, im, other, st
    }' "$RESOLVE" "$TASKS" "$CLASSES"
  ;;
*) echo "unknown table $what"; exit 2 ;;
esac
