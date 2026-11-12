We need to expose the draft-pick write flows through the API and MCP, and add an admin-only correction path for draft picks.

## Drafting with a pick

Add authenticated `POST /api/v1/draft_picks/:id/draft_player` and an MCP tool named `draft_player`.

The REST body is under `draft_pick` and carries `fantasy_player_id`; all other fields come from the pick itself. Owners may draft with a pick owned by one of their teams. Admins may draft with any pick. A non-owner gets a 403, and the attempt is audited as denied.

The draft must use the same rules and side effects as the existing draft page: the pick must be up, flex spots must be available, the player must not already have been drafted in the league, and a valid player id must resolve to an existing player. A missing player id must produce a changeset error on `fantasy_player_id` with “can't be blank”, and a nonexistent player must produce `fantasy_player_id` “is invalid” rather than crashing. On success it must create the roster position, mark any matching draft queue entry as drafted, reorder the league’s queues, send the usual draft update notification, and start the same autodraft follow-on used by the HTML draft flow after its usual delay.

Successful REST drafting returns 200 with `{"draft_pick": ...}` containing the refreshed pick, including the drafted player and `drafted_at`. A missing or unparseable pick id returns 404. If the pick has no `fantasy_team_id`, return 422 with a `fantasy_team_id` error. If the league has `draft_picks_locked?` set, return 422 with the message “Draft picks are locked for this league”; this applies to admins as well. Changeset failures return 422 in the usual `{"errors": %{field => [messages]}}` shape.

The MCP tool takes `draft_pick_id` and `fantasy_player_id`. Success returns a JSON summary with `id`, `draft_position`, `fantasy_league_id`, `fantasy_team_id`, `team_name`, `fantasy_player_id`, `player_name`, `is_keeper`, and `drafted_at`. A missing pick is a tool error whose text contains “Not found”; non-owner is “not authorized”; locked league text contains “locked”; missing player, nonexistent player, or a pick with no team are “Validation failed” tool errors, not crashes. Audit source must be `"mcp"`, action `draft_pick.draft_player`, with resource id equal to the draft pick id on success.

## Admin correction path

Add authenticated `PATCH /api/v1/draft_picks/:id` and an MCP tool named `update_draft_pick`. This is admin-only: owners get 403 even for their own picks, and denied attempts are audited.

The only correctable fields are `fantasy_team_id`, `draft_position`, `is_keeper`, and `drafted_at` (ISO 8601 string or null). Ignore `fantasy_league_id` and `fantasy_player_id` entirely; sending them should still return success with those fields unchanged. A changed `fantasy_team_id` must be present and must exist; a nonexistent team gives “does not exist”, a team from another league gives “must belong to the pick's league”, and clearing it gives “can't be blank”. A pick that has already been used (`fantasy_player_id` set) cannot be moved to another team; return an error containing “can't be changed once the pick has been used”.

This correction writes only the pick row. It must not create a roster position, touch draft queues, or broadcast on the draft-pick topic. It should work even when the league’s `draft_picks_locked?` is true. REST success returns 200 with `{"draft_pick": ...}`. Missing or unparseable ids return 404. MCP success returns the same summary shape as `draft_player`; missing pick is “Not found”, non-admin is “not authorized”, and validation errors are “Validation failed” with the encoded errors.

Add `DraftPicks.update_draft_pick/2` as the direct context entry point for this correction: it takes a pick struct and params and returns `{:ok, updated_pick}` or `{:error, changeset}`. It must not broadcast. Keep the existing bang lookup behavior intact; the API/MCP paths should tolerate untrusted id strings by treating missing or non-numeric ids as not found rather than raising a cast error.

## Rendering

REST write responses use one `draft_pick` object with `id`, `draft_position`, `fantasy_team` (`id` and `team_name`, or null), `fantasy_player` data, `drafted_at`, and `is_keeper`. Do not include `pick_number` in these write responses, not even as null; it depends on the whole board and should not overwrite a client’s cached pick number. The existing league draft-pick index keeps its current shape and may still include `pick_number`. Rendering must also tolerate a pick with no team or no player.

## MCP read tool

Add `list_league_draft_picks` with a required `fantasy_league_id`. It uses the same private-league access rule as the other league read tools; a non-member reading a private league gets a tool error containing “not authorized”. Success returns JSON `{"draft_picks": [...]}`. Each item has `id`, `draft_position`, `fantasy_league_id`, `fantasy_team_id`, `team_name`, `fantasy_player_id`, `player_name`, `is_keeper`, `drafted_at`, `pick_number`, and `available_to_pick?`. For a fresh league’s first pick, `pick_number` is 1 and `available_to_pick?` is true.

The MCP tool list must advertise `list_league_draft_picks`, `draft_player`, and `update_draft_pick` with object input schemas using the fields above and `additionalProperties: false`. Missing required tool arguments such as `draft_pick_id` or `fantasy_league_id` should produce invalid-params tool errors.

## Audit and compatibility

Both API and MCP draft and correction attempts should go through the existing audit mechanism, with actions `draft_pick.draft_player` and `draft_pick.update`, the correct `"api"` or `"mcp"` source, success/denied outcome, resource type `DraftPick`, and league id whenever the pick exists. Successful draft audit entries must reference the draft pick id.

Keep the existing HTML draft flow compatible and reuse its drafting behavior rather than creating a separate set of rules. Do not add any way for a correction to change the drafted player or move a pick to another league. Do not move roster positions or draft queues when correcting, and do not broadcast correction changes.
