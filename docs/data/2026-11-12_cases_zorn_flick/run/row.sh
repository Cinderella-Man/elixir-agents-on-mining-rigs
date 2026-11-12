#!/usr/bin/env bash
# row.sh: one.sh's result line for one try, from the files of its folder OUT only, so that it can be written again
# from them: outcome.tsv (what one.sh decided: the folder's origin and, without a check, the verdict), times.tsv,
# state_before.json, state_after.json (and from them images_added.tsv), check.json, result.json; and the watcher's
# samples (WATCH) for the highest 1-minute load during the check. A check is settled when that load stayed under
# SETTLE_LOAD (12); a refusal before the check is settled by itself.
# Environment: OUT, WATCH, REPOSITORY, NUMBER, ID, SETTLE_LOAD (12).
# Writes OUT/row.tsv: repository, number, id, folder, make_s, import_s, check_s, export_s, verdict, dropped_at, reason,
# steps_ms (the engine's <step>_ms), load_start, load_end, load_max_check, settled, images_added (name bytes; ...),
# images_bytes, cache_bytes_before, cache_bytes_after, free_before, free_after, job, start, end, detail (one line, its
# first 300 characters). Prints its first 16 columns.
set -euo pipefail
: "${OUT:?}" "${WATCH:?}" "${REPOSITORY:?}" "${NUMBER:?}" "${ID:?}"
SETTLE_LOAD=${SETTLE_LOAD:-12}
get() { [ -f "$OUT/outcome.tsv" ] || return 0; awk -F'\t' -v k="$1" '$1 == k {sub(/^[^\t]*\t/, ""); v = $0} END {print v}' "$OUT/outcome.tsv"; }
secs() { awk -F'\t' -v s="$1" '$1 ~ ("^" s "$") {t += $4; n++} END {print (n ? t : "-")}' "$OUT/times.tsv"; }
when() { awk -F'\t' -v s="$1" -v c="$2" '$1 == s {v = $c} END {print (v == "" ? "-" : v)}' "$OUT/times.tsv"; }

folder=$(get folder)
if [ -z "$folder" ]; then
  if [ -d "$OUT/make" ]; then folder=made
  elif jq -e --arg id "$ID" '.ok | any(.id == $id and (.result == "imported" or .result == "unchanged"))' "$OUT/import_copied.json" > /dev/null 2>&1; then folder=copied
  else folder=held; fi
fi
if [ -f "$OUT/result.json" ]; then
  verdict=$(jq -r '.verdict' "$OUT/result.json")
  dropped_at=$(jq -r '.dropped_at // "-"' "$OUT/result.json")
  reason=$(jq -r '(.reason // "-") | tostring' "$OUT/result.json")
  detail=$(jq -r '(.detail // "-") | tostring' "$OUT/result.json")
  steps_ms=$(jq -r '[to_entries[] | select(.key | endswith("_ms")) | "\(.key)=\(.value)"] | join(" ")' "$OUT/result.json")
else
  verdict=$(get verdict); dropped_at=$(get dropped_at); reason=$(get reason); detail=$(get detail); steps_ms=-
fi
# images present after and not before: their tags, or their repository digests when they have none, and bytes
jq -r --slurpfile b "$OUT/state_before.json" '
  ($b[0].images | map(.id)) as $old |
  .images[] | select(.id as $i | $old | index($i) | not) |
  [.id, ((if (.names | map(select(test("@sha256:") | not)) | length) > 0 then (.names | map(select(test("@sha256:") | not))) else .digests end) | unique | join(" ") | if . == "" then "-" else . end), .bytes] | @tsv' \
  "$OUT/state_after.json" > "$OUT/images_added.tsv"
job=$(jq -r '.ok // "-"' "$OUT/check.json" 2>/dev/null || echo -)
check_start=$(when check 2); check_end=$(when check 3)
load_start=$(jq -r '.load | split(" ") | .[0]' "$OUT/state_before.json")
load_end=$(jq -r '.load | split(" ") | .[0]' "$OUT/state_after.json")
t_start=$(jq -r '.time' "$OUT/state_before.json")
t_end=$(jq -r '.time' "$OUT/state_after.json")
images_added=$(awk -F'\t' '{printf "%s%s %s", (NR > 1 ? "; " : ""), $2, $3}' "$OUT/images_added.tsv")
images_bytes=$(awk -F'\t' '{s += $3} END {print s + 0}' "$OUT/images_added.tsv")
cache_before=$(jq -r '.build_cache.bytes' "$OUT/state_before.json")
cache_after=$(jq -r '.build_cache.bytes' "$OUT/state_after.json")
free_before=$(jq -r '.free_bytes' "$OUT/state_before.json")
free_after=$(jq -r '.free_bytes' "$OUT/state_after.json")
max_load=-; settled=-
if [ "$check_start" != - ]; then
  max_load=$(awk -F'\t' -v a="$check_start" -v b="$check_end" 'NR > 1 && $1 >= a && $1 <= b && $2 + 0 > m + 0 {m = $2} END {print m + 0}' "$WATCH")
  settled=$(awk -v m="$max_load" -v s="$SETTLE_LOAD" 'BEGIN {print (m < s ? "settled" : "not settled")}')
fi
[ "$verdict" != refused ] || settled=settled
detail1=$(printf '%s' "${detail:--}" | tr '\t\n' '  ' | cut -c1-300)
printf '%s\t' "$REPOSITORY" "$NUMBER" "$ID" "$folder" "$(secs make)" "$(secs "import(_copied)?")" "$(secs check)" "$(secs export)" \
  "${verdict:--}" "${dropped_at:--}" "${reason:--}" "${steps_ms:--}" "$load_start" "$load_end" "$max_load" "$settled" \
  "${images_added:--}" "$images_bytes" "$cache_before" "$cache_after" "$free_before" "$free_after" "$job" "$t_start" "$t_end" > "$OUT/row.tsv"
printf '%s\n' "${detail1:--}" >> "$OUT/row.tsv"
cut -f1-16 "$OUT/row.tsv"
