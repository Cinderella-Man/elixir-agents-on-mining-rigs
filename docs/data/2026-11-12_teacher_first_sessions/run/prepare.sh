#!/usr/bin/env bash
# prepare.sh: import the tasks into a new controller, list what its inventory holds for each, then run the factory's
# preparation and controls on them with no model (Eab.Runs.prepare/1: the workspace images, the database, and the
# grader's controls with their second round), one task at a time. A new controller has no saved controls, so this is
# the check of each task in this environment; the runs that follow reuse it ("Reusing checked fixture").
# Environment: CTL, NAME, SRC (the factory folder: bin/factoryctl), CONTROLLER (this folder's controller.sh), SOURCES
# (the folder of task folders, mounted read only in the controller), TASKS (one id per line), OUT, TICK (30).
# Writes OUT/import.json, OUT/inventory.tsv (id, ticket.md, statement.json, writer's model, the record's SHA-256 matches
# ticket.md, kind, ticket.md bytes), OUT/prepare.log, OUT/preparation.json (the job's record with one result per task)
# and OUT/prepare.done (0 when every task's controls are valid, 1 otherwise) last.
set -uo pipefail
: "${CTL:?}" "${NAME:?}" "${SRC:?}" "${CONTROLLER:?}" "${SOURCES:?}" "${TASKS:?}" "${OUT:?}"
TICK=${TICK:-30}
mkdir -p "$OUT"
rm -f "$OUT/prepare.done"
log() { echo "$(date -u +%FT%TZ) $*" >> "$OUT/prepare.log"; }
ctl() { NAME=$NAME "$SRC/bin/factoryctl" "$@"; }
rpc() { CTL=$CTL NAME=$NAME "$CONTROLLER" rpc "$1" | grep -v '^=ESOCK\|libsctp'; }

ctl import "$SOURCES" > "$OUT/import.json" 2>&1
log "import: $(jq -c '.ok | map_values(length)? // .' "$OUT/import.json" 2>/dev/null | head -c 300)"
rpc 'Eab.Inventory.all() |> Enum.each(fn id -> t = Eab.Inventory.case_path(id, "ticket.md"); s = Eab.Inventory.case_path(id, "statement.json"); c = Eab.Inventory.read_json(Eab.Inventory.case_path(id, "case.json")); r = if File.regular?(s), do: Eab.Inventory.read_json(s), else: %{}; IO.puts(Enum.join([id, File.regular?(t), File.regular?(s), get_in(r, ["writer", "model"]) || "", File.regular?(t) and r["ticket_sha256"] == Eab.Inventory.hash_file(t), c["task_kind"], if(File.regular?(t), do: File.stat!(t).size, else: 0)], "\t")) end)' \
  > "$OUT/inventory.tsv"
log "inventory: $(grep -c . "$OUT/inventory.tsv") tasks"

ids=$(grep . "$TASKS" | sed 's/.*/"&"/' | paste -sd, -)
started=$(date +%s)
rpc "IO.puts(inspect(Eab.Runs.prepare([$ids])))" >> "$OUT/prepare.log" 2>&1
log "preparation started for $(grep -c . "$TASKS") tasks"
while :; do
  sleep "$TICK"
  ctl status > "$OUT/status.json" 2>/dev/null
  jq -e '.ok.preparation == null and .ok.cleaning != true' "$OUT/status.json" > /dev/null 2>&1 && break
  line=$(jq -r '.ok.preparation | "\(.finished)/\(.total) \(.message)"' "$OUT/status.json" 2>/dev/null | head -c 300)
  [ "$line" != "${last:-}" ] && { log "status: $line"; last=$line; }
done
job=$(ls -t "$CTL/data/jobs" | grep '^preparation-' | head -n 1)
cp "$CTL/data/jobs/$job/job.json" "$OUT/preparation.json"
log "preparation $job ended after $(( $(date +%s) - started )) s: $(jq -r '.status' "$OUT/preparation.json")"
jq -r '.results[] | [.case, .status, (.valid|tostring), (.error // "")] | @tsv' "$OUT/preparation.json" >> "$OUT/prepare.log"
if jq -e '[.results[] | .valid == true] | all' "$OUT/preparation.json" > /dev/null; then rc=0; else rc=1; fi
echo "$rc" > "$OUT/prepare.done"
