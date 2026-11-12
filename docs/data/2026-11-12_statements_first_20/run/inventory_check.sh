#!/usr/bin/env bash
# inventory_check.sh: start the stopped controller, import a folder of task folders that now have statements, list
# what its inventory holds for each task, and stop the controller again. The import runs the factory's import check,
# which refuses a task whose statement.json does not name its writer or does not hold ticket.md's SHA-256 (factory
# README, section 3.4).
# Environment: CTL (the controller's own folder), NAME (its container), SRC (the factory folder: bin/factoryctl),
# CONTROLLER (the set-up's controller.sh), IMPORT (a folder of task folders that the controller mounts), OUT.
# Writes OUT/import.json (the import's answer) and OUT/inventory.tsv (id, ticket.md, statement.json, writer's model,
# whether the record's SHA-256 matches ticket.md).
set -euo pipefail
: "${CTL:?}" "${NAME:?}" "${SRC:?}" "${CONTROLLER:?}" "${IMPORT:?}" "${OUT:?}"
mkdir -p "$OUT"
CTL=$CTL NAME=$NAME "$CONTROLLER" start
NAME=$NAME "$SRC/bin/factoryctl" import "$IMPORT" | tee "$OUT/import.json"
CTL=$CTL NAME=$NAME "$CONTROLLER" rpc 'Eab.Inventory.all() |> Enum.each(fn id -> t = Eab.Inventory.case_path(id, "ticket.md"); s = Eab.Inventory.case_path(id, "statement.json"); r = if File.regular?(s), do: Eab.Inventory.read_json(s), else: %{}; IO.puts(Enum.join([id, File.regular?(t), File.regular?(s), get_in(r, ["writer", "model"]) || "", File.regular?(t) and r["ticket_sha256"] == Eab.Inventory.hash_file(t)], "\t")) end)' |
  grep -v '^=ESOCK\|libsctp' | tee "$OUT/inventory.tsv"
CTL=$CTL NAME=$NAME "$CONTROLLER" stop
