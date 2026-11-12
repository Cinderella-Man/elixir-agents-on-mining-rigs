#!/usr/bin/env bash
# The first run of the converter: the tests, then the kept sessions of one project, then the sessions that were not
# kept (into a folder of their own, only to see that the converter does not fail on them), each with its checks.
#
#   SRC       a checkout of this repository
#   SESSIONS  the clone of the raw-sessions repository (sessions.tsv and raw/)
#   OUT       where the records of the kept sessions go
#   OUT_NOT   where the records of the sessions that were not kept go
#   TABLES    where the tables go (numbers only)
#   PROJECT   the project to convert (default axelclark__ex338)
#   PY        the Python to use (default python3)
set -euo pipefail
: "${SRC:?}" "${SESSIONS:?}" "${OUT:?}" "${OUT_NOT:?}" "${TABLES:?}"
PROJECT=${PROJECT:-axelclark__ex338}
PY=${PY:-python3}
TOOL=$SRC/tools/training_data
mkdir -p "$TABLES"

echo "== tests"
nice -n 19 "$PY" -I "$TOOL/tests/test_converter.py" 2>&1 | tail -n 4
nice -n 19 "$PY" -I "$TOOL/switches.py" > "$TABLES/switches.tsv"

echo "== kept sessions"
nice -n 19 "$PY" -I "$TOOL/convert_sessions.py" --index "$SESSIONS/sessions.tsv" --root "$SESSIONS" --kept yes \
  --project "$PROJECT" --out "$OUT"
nice -n 19 "$PY" -I "$TOOL/check_records.py" --records "$OUT" --out "$TABLES/kept"
cp "$OUT/records.tsv" "$OUT/errors.tsv" "$OUT/run.json" "$TABLES/kept/"

echo "== sessions that were not kept"
nice -n 19 "$PY" -I "$TOOL/convert_sessions.py" --index "$SESSIONS/sessions.tsv" --root "$SESSIONS" --kept no \
  --project "$PROJECT" --out "$OUT_NOT"
nice -n 19 "$PY" -I "$TOOL/check_records.py" --records "$OUT_NOT" --out "$TABLES/not_kept"
cp "$OUT_NOT/records.tsv" "$OUT_NOT/errors.tsv" "$OUT_NOT/run.json" "$TABLES/not_kept/"
