I want three new MCP tools around fantasy team draft queues: `reorder_draft_queues`, `delete_draft_queue`, and `update_autodraft_setting`. Add them to the existing tool list with their `inputSchema` maps, and send them through the same MCP authorization/audit path as the other tools. Existing tool names and payload shapes must stay unchanged.

`reorder_draft_queues`

- Input: required `fantasy_team_id` integer and `draft_queue_ids` array of integers. The array order is the new draft order, so the first id becomes `order` 1.
- Only the team's owner or an admin may do this. Otherwise return the normal tool error whose text contains “not authorized”, change nothing, and audit the denial.
- Look up the team first. An unknown team id, including `0`, is a normal not-found tool error whose text contains “Not found”, regardless of the ids passed.
- The ids must name every pending draft queue for that team exactly once. No missing ids, no extra ids, no duplicates, and no ids belonging to another team. A partial list must be rejected rather than applied.
- On an id mismatch, return an invalid-params JSON-RPC error with code `-32602` and a message that mentions “exactly once”; do not change any order values. This is not the normal `isError` tool-result form.
- On success, set `order` to 1 through the list length in the requested order atomically. Return a JSON object with a `draft_queues` array in the new order; each entry must include `id` and the usual draft-queue fields. Afterward, `DraftQueues.list_team_queues/1` for that team must return the entries in that same order with contiguous `order` values. An empty list is valid only for a team with no pending queues.
- Audit success with action `"draft_queue.reorder"`, source `"mcp"`, and outcome `"success"`.

`delete_draft_queue`

- Input: required `draft_queue_id` integer.
- Look up the queue by id first. An unknown or malformed client-supplied id must be treated as a normal not-found tool error whose text contains “Not found”; it must not raise.
- Authorize against the queue’s own team, not against any team supplied separately. The queue team’s owner or an admin may delete; everyone else gets the normal tool error whose text contains “not authorized”, the queue stays in place, and the audit outcome is `"denied"`.
- On success, delete the queue and renumber the remaining pending queues for that same team to contiguous `order` values starting at 1, preserving their existing relative order. This must happen atomically. Deleting the first of three should leave the old second at 1 and the old third at 2.
- Return a JSON object for the deleted queue summary; it must include `id`.
- Audit success with action `"draft_queue.delete"`, source `"mcp"`, and outcome `"success"`. The audit’s `fantasy_league_id` must be the queue team’s league id, since the queue itself has no league field.

`update_autodraft_setting`

- Input: required `fantasy_team_id` integer and `autodraft_setting` string limited to `"on"`, `"off"`, or `"single"`.
- Look up the team first. An unknown team id is a normal not-found tool error whose text contains “Not found”.
- Only the team’s owner or an admin may change it. Otherwise return the normal tool error whose text contains “not authorized”, leave the setting unchanged, and audit the denial.
- Change only `autodraft_setting`; do not touch draft queues, rosters, or other team fields. The existing field stores atoms `:on`, `:off`, and `:single`.
- On an unrecognized setting, return the normal validation tool error whose text contains “Validation failed” and leave the setting unchanged.
- On success, return a JSON object for the updated team summary with `autodraft_setting` serialized as a string such as `"on"`.
- Audit success with action `"fantasy_team.autodraft_setting"`, source `"mcp"`, and outcome `"success"`.

Keep the existing autodraft and queue-listing behavior compatible. This is only about exposing these three MCP tools and their authorization/audit semantics; no UI or REST endpoint changes.
