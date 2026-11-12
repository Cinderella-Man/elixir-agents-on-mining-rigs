We need Slack link previews for NervesHub links, along with the Slack permissions and the reinstall message this requires.

## Slack app scopes

`Slack.scopes/0` must include `links:read` and `links:write`, appended in this order to the existing scopes:

`chat:write,chat:write.public,channels:read,groups:read,commands,links:read,links:write`

That same comma-separated list must be sent in the OAuth authorization URL and stored on newly connected workspaces. Existing connections must not be altered automatically.

In the organization’s Slack connection section, when a connected workspace’s scopes do not include `links:write`, show this note under that connection:

“To preview NervesHub links posted in this workspace, an admin of this organization installs the app again: Add to Slack, then choose {team name}.”

Use the friendly platform name and the connected workspace’s team name. Do not show the note when `links:write` is present.

## Event handling

For an `event_callback` with a binary `team_id` and an event of type `link_shared`, answer Slack with a 200 immediately and do the preview work in the background, without waiting for the preview result before responding. Pass the `team_id` and the event to the new unfurl implementation. Other Slack events must continue to be handled as they are now, and events NervesHub ignores must still get a 200.

## Link previews

Add `NervesHubWeb.Integrations.Slack.Unfurls` with two public functions.

`Unfurls.page/1` takes a URL and returns:

- `{:device, org_name, product_name, device_identifier}`
- `{:deployment_group, org_name, product_name, deployment_group_name}`
- `nil` for anything else

Only `http` and `https` URLs count. The host must match this instance’s `NervesHubWeb.Endpoint.url()` host, case-insensitively. Resolve the path as a GET route and only accept device and deployment-group pages, with any tab suffix such as `/health`, `/logs`, `/settings`, or `/releases` allowed. Decode path parameters once, so names like `thermo%20stat` become `thermo stat`. `/org/acme/thermostat/devices/new`, the devices index, foreign hosts, and non-http schemes return `nil`.

`Unfurls.unfurl/2` takes `team_id` and the `link_shared` event and returns exactly one of `:unfurled`, `:asked_to_link`, or `:nothing`.

The event has `"links"`, a list of maps with `"url"`, and `"user"`, the Slack user id. Ignore malformed entries and missing pieces. Collect the link URLs, deduplicate them, map each URL through `Unfurls.page/1`, discard non-NervesHub pages, and keep at most the first five valid pages. If there are none, return `:nothing`.

A preview is tied to either a posted message or a link being typed:

- If the event has binary `"unfurl_id"` and `"source"`, send those as the message identity.
- Otherwise use `"channel"` and `"message_ts"` as the message identity.
- If neither identity is available, return `:nothing`.

A workspace must exist for the `team_id`, with a bot token, or return `:nothing`.

Look up the NervesHub user linked to that Slack user in that workspace. If the Slack user has not linked an account:

- Send a `chat.unfurl` request with `user_auth_required: true`
- Use the link-message blocks as `user_auth_blocks`
- Give the link message the purpose “to see its links previewed here”
- Do not include an `unfurls` key
- Return `:asked_to_link`

The link button must continue to point at `/integrations/slack/link?team=...`.

If the Slack user is linked, check each page before previewing it. Device pages need `Actions.authorize_in/6` with `:device:view`, described as seeing devices. Deployment-group pages use `nil` permission, meaning any member role that passes the connection and membership checks. Missing organizations, products, deployment groups, and deleted or missing devices are skipped silently. A link the poster may not see gets no preview and no explanation. If no page produces a preview, return `:nothing` and do not call Slack.

When at least one page produces a preview, send `chat.unfurl` with:

- the message identity described above
- an `unfurls` map keyed by the original URL string
- each value as a map containing `blocks`

Return `:unfurled`.

Device previews should use the same device-card content as the existing Slack device messages, but with no buttons. Include the normal connection/firmware/health/product fields, so an online device has `*Connection*\nOnline`.

Deployment-group previews are a single section block. Its heading is the escaped deployment-group name in asterisks, such as `*production*`. Its fields are:

- `Status`: `Active` or `Paused`
- `Release`: `"<number>, firmware <version>"` when the release has a firmware version, otherwise the release number
- `Workflow`: where the current workflow stands
- `Devices`: the deployment group’s device count, or `0`
- `Product`: the escaped product name

Leave out any field whose value is nil. Sort workflow steps by step number. If there are no steps, omit `Workflow`. Otherwise:

- Any step with status `:error`: `"<label> failed (step N of M)"`
- Otherwise, an `:approval_required` step with no `approved_at`: `"Waiting for approval at <label> (step N of M)"`
- Otherwise, a step in progress: `"<label> (step N of M)"`
- Otherwise: `"Not started"`

`N` is the step number, `M` is the total number of steps, and labels are escaped with the existing Slack escaping helper.

## Authorization and link messages

Extend `Actions.authorize_in/6` so `permission` may be `nil`. A nil permission still requires the organization to be connected to the workspace and the user to be a member of that organization, but does not require a role permission. Existing atom permissions must behave as before.

The existing link message must keep its current wording for existing callers. Make the purpose configurable with the current text as the default, and append a period after the purpose where it is currently used. The unfurl use is the specific “to see its links previewed here” wording described above.

## Slack client and failures

The Slack client must support posting `chat.unfurl` with the workspace bot token and a JSON body. Preview request failures should be logged and must not crash the event handling or block Slack’s response. Previews must never include buttons, and only links to this instance’s own device and deployment-group pages may be previewed.
