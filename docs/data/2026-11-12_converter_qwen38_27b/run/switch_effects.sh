#!/usr/bin/env bash
# What each switch changes in the kept sessions: convert them again with one switch moved (or with another template
# file) and count the records whose text changes. Writes $TABLES/switch_effects.tsv.
#
#   SRC, SESSIONS, OUT  as in first_run.sh (OUT is the first run's folder, read only here)
#   WORK      a folder of one's own for the other records (deleted at the end)
#   TABLES    where the table goes
set -uo pipefail
: "${SRC:?}" "${SESSIONS:?}" "${OUT:?}" "${WORK:?}" "${TABLES:?}"
PROJECT=${PROJECT:-axelclark__ex338}
PY=${PY:-python3}
TOOL=$SRC/tools/training_data
TEMPLATES=$SRC/docs/data/2026-11-12_target_text_qwen38_27b/templates
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$WORK/switch" "$TABLES"
printf 'change\trecords\tnot_converted\ttext_changes_in\ttext_bytes\ttext_bytes_first_run\tfixed_text_changes\trecords_with_problems\n' \
  > "$TABLES/switch_effects.tsv"

one() {  # label, then either "switch name=value" or "template file"
  local label=$1 kind=$2 value=$3 dir=$WORK/switch/run
  rm -rf "$dir"
  if [ "$kind" = switch ]; then
    nice -n 19 "$PY" -I "$TOOL/convert_sessions.py" --index "$SESSIONS/sessions.tsv" --root "$SESSIONS" --kept yes \
      --project "$PROJECT" --out "$dir" --switch "$value" > /dev/null 2>&1
  else
    TEMPLATE=$value nice -n 19 "$PY" -I "$TOOL/convert_sessions.py" --index "$SESSIONS/sessions.tsv" \
      --root "$SESSIONS" --kept yes --project "$PROJECT" --out "$dir" > /dev/null 2>&1
  fi
  problems=$(TEMPLATE=$([ "$kind" = template ] && echo "$value" || echo "") nice -n 19 "$PY" -I \
    "$TOOL/check_records.py" --records "$dir" 2> /dev/null | tail -n 1)
  nice -n 19 "$PY" -I "$HERE/switch_effects.py" "$label" "$OUT/records.tsv" "$dir/records.tsv" "$dir/errors.tsv" \
    "$problems" >> "$TABLES/switch_effects.tsv"
}

one "trim=c_isspace" switch "trim=c_isspace"
one "param_order=sorted" switch "param_order=sorted"
one "integral_floats=keep" switch "integral_floats=keep"
one "json_ensure_ascii=true" switch "json_ensure_ascii=true"
one "json_escape_html=true" switch "json_escape_html=true"
one "json_item_separator=," switch "json_item_separator=,"
one "json_key_separator=:" switch "json_key_separator=:"
one "begin_token=<|endoftext|>" switch "begin_token=<|endoftext|>"
one "enable_thinking=true" switch "enable_thinking=true"
one "reasoning_effort=xhigh" switch "reasoning_effort=xhigh"
one "reasoning_effort=high" switch "reasoning_effort=high"
one "reasoning_effort=medium" switch "reasoning_effort=medium"
one "reasoning_effort=low" switch "reasoning_effort=low"
one "preserve_thinking=true" switch "preserve_thinking=true"
one "preserve_thinking=false" switch "preserve_thinking=false"
one "jinja_trim_blocks=false" switch "jinja_trim_blocks=false"
one "jinja_lstrip_blocks=false" switch "jinja_lstrip_blocks=false"
one "no_thinking_field=empty" switch "no_thinking_field=empty"
one "no_thinking_field=null" switch "no_thinking_field=null"
one "final_tool_calls_field=empty" switch "final_tool_calls_field=empty"
one "template: the maker's file of 2026-11-07" template "$TEMPLATES/maker_chat_template_2026-11-07.jinja"
one "template: the maker's file of 2026-08-13" template "$TEMPLATES/maker_chat_template_2026-08-13.jinja"
rm -rf "$WORK/switch"
cat "$TABLES/switch_effects.tsv"
