#!/usr/bin/env bash
# collect.sh: after a run of run_all.sh, copy what is published and pack what is not.
# For each case of the list that holds a statement: ticket.md and statement.json into DEST/statements/<case id>/.
# The driver's own records (tasks.tsv, run.log, props.json) into DEST. Every request, answer and record of the run
# (with the model's thinking text; not published) into one archive, RAW.
# Environment: WORK (case folders in WORK/tasks), OUT (the run's folder), DEST (a new folder), RAW (the archive's path).
# Usage: collect.sh <case list>
set -euo pipefail
: "${WORK:?}" "${OUT:?}" "${DEST:?}" "${RAW:?}"
list=${1:?case list}
mkdir -p "$DEST/statements"
n=0
while IFS=$'\t' read -r folder _; do
  [ -n "$folder" ] || continue
  id=$(basename "$folder")
  if [ -f "$WORK/tasks/$folder/ticket.md" ] && [ -f "$WORK/tasks/$folder/statement.json" ]; then
    mkdir -p "$DEST/statements/$id"
    install -m 644 "$WORK/tasks/$folder/ticket.md" "$WORK/tasks/$folder/statement.json" "$DEST/statements/$id/"
    n=$((n + 1))
  fi
done < "$list"
install -m 644 "$OUT/tasks.tsv" "$OUT/run.log" "$OUT/props.json" "$DEST/"
tar -C "$(dirname "$OUT")" -czf "$RAW" "$(basename "$OUT")"
echo "$n statements copied; archive $(wc -c < "$RAW") bytes"
