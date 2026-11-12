Deployment workflow steps need to surface through the organization's integrations and be actionable from Slack.

Add these integration event keys everywhere integrations are listed, using the group/labels we already use for workflows:
- `deployment_group.workflow_step.started`
- `deployment_group.workflow_step.awaiting_approval`
- `deployment_group.workflow_step.completed`
- `deployment_group.workflow_step.failed`
- `deployment_group.workflow_step.skipped`

They belong in the webhook event catalog under `Deployment workflows`, and in the Slack event catalog with labels such as `Workflow step started`, `Workflow waiting for approval`, `Workflow step completed`, `Workflow step failed`, and `Workflow step skipped`. The Slack event keys and sources use the same strings.

The event payload should describe the deployment workflow step, not a device. It should contain:
- `org: %{name: ...}` and `product: %{name: ...}` as the other organization events do.
- `deployment_group: %{name: ...}`.
- `release: %{number: ..., firmware: %{uuid: ..., version: ...}}`.
- `workflow: %{steps: <total number of steps in that release, including the automatic catch-all>}`.
- `step: %{id:, number:, name:, type:, status:, started_at:, finished_at:}`. `name` is the existing workflow step label, `type` and `status` are strings such as `"update_devices"`, `"approval_required"`, `"catch_all"`, `"waiting"`, `"in_progress"`, `"completed"`, `"error"`, and `"skipped"`. Timestamps are ISO8601 UTC strings, with `nil` when absent.
- `user: nil` or `%{name: <NervesHub user name>}`.
- `failed_devices: nil` or an integer.

The workflow transitions should raise these events so the orchestrator, the deployment group page and Slack all produce the same announcements:
- Starting a step raises `started`, except an approval-required step raises `awaiting_approval` instead.
- Completing a step raises `completed`; for an approval step the user is the approver.
- Failing a step raises `failed` and carries the number of devices that failed. The orchestrator should pass the same failed-device count it already computes. Keep the existing one-argument call compatible; the count is an optional argument.
- Skipping raises `skipped` with the user who skipped.
- Retrying raises `started` with the user who retried.

Do not announce anything when the step's release or deployment group can no longer be resolved.

Slack pending events must no longer be posted in the order they appear in settings. When events are grouped by type, post each type's message in the order that type's first event occurred, using the stored event id. For example, if a completion and the next step's start arrive together, the completion should post first if it happened first.

Slack messages for the new events:
- Build one message per event type. Show at most five steps, each in its own section, then a context line `And N more on the deployment groups' pages.` when there are more.
- For a single event, the message text is the plain version of the step heading. For several, it is `"<count> workflow steps <verb>"`, where `awaiting_approval` uses `waiting for approval` and the other verbs are the event names.
- Each step heading links the deployment group to `<Endpoint.url()>/org/<org>/<product>/deployment_groups/<group>`, bolds the step name in Slack markdown, and includes the position when both the step number and total step count are integers: `*Canary* (step 1 of 3)`.
- Use these plain heading forms:
  - started without a user: `Canary (step 1 of 3) started for production`
  - started with a user: `Alice retried Canary (step 1 of 3) for production`
  - awaiting approval: `production is waiting for approval at Sign-off (step 2 of 3)`
  - completed without a user: `Canary (step 1 of 3) completed for production`
  - completed with a user: `Alice approved Canary (step 2 of 3) for production`
  - skipped without a user: `Canary (step 1 of 3) was skipped for production`
  - skipped with a user: `Alice skipped Canary (step 1 of 3) for production`
  - failed: `Canary (step 1 of 3) failed for production: 3 devices could not take the update. The rollout is stopped until the step is retried or skipped.` Use singular wording for one failed device, and omit the count sentence if the count is absent.
- Each shown step has a context block with the product name and `release <number>, firmware <version>` (or just `release <number>` when there is no firmware version).
- A waiting-for-approval message has an `Approve` button using action id `workflow_step.approve`, style `primary`, value the step id as a string, with confirmation title `Approve <step name>?`, text `The rollout carries on with the next step.`, and confirm label `Approve`.
- A failed message has `Retry` (`workflow_step.retry`, primary) and `Skip` (`workflow_step.skip`, danger) buttons, both carrying the step id, each with a confirmation. Add an `Open` button with action id `deployment_group.open` and the deployment group URL. The order is Retry, Skip, Open.
- Awaiting approval is Approve, Open.
- Started, completed and skipped messages have no buttons.
- If the step id or deployment group URL needed for a button is missing, omit that action block.
- All names supplied by users must be escaped so people cannot inject Slack links or mentions through step or deployment group names.

Add `NervesHubWeb.Integrations.Slack.WorkflowSteps` with:
- `click/2`: takes the Slack interaction payload and the clicked action map. It recognises `workflow_step.approve`, `workflow_step.retry`, and `workflow_step.skip`, casts the value to a step id, and returns the same click map shape the device buttons use: `action`, `step_id`, `team_id`, `slack_user_id`, `slack_username`, `response_url`, `channel_id`, and `message_ts`. Return `nil` for an unknown action, a non-integer value, or a payload that does not identify the team/user.
- `perform/1`: returns `{:ok, :approve | :retry | :skip}` or `{:error, reason}`.

`perform/1` checks in this order and reports the first failure:
1. Resolve the linked NervesHub user for the Slack team/user. If there is none, return `{:error, :not_linked}` and send the existing link message.
2. Read the step, its release, and the deployment group with its organization. If any are gone, return `{:error, :no_step}` and reply `That workflow step is no longer in NervesHub.`
3. Authorize against the deployment group's organization using the same workspace-connected, organization-member, role checks as device buttons, with permission `deployment_group:update`, subject `that deployment group`, and the verb `approve`/`retry`/`skip`. A viewer trying to approve gets exactly `Your role in NervesHub does not let you approve deployment workflow steps.` Use the existing not-connected and not-member messages.
4. The step must belong to the deployment group's current release. Otherwise return `{:error, :superseded}` and reply that the step is part of an earlier release of the deployment group.
5. Check that the action is still possible before claiming it:
   - Approve only works on an approval-required step that has not been approved and is still in progress. If it was already approved, return `{:error, :already_done}` and reply `*<step>* was already approved by <name>.` If it is no longer waiting, return `{:error, :already_done}` and say what state it is in.
   - Retry only works for a retryable step. Otherwise return `{:error, :not_retryable}` with `Only a failed step can be retried, and *<step>* is running.`-style wording based on the step's state.
   - Skip only works for a skippable step; the final catch-all cannot be skipped. Otherwise return `{:error, :not_skippable}`.
6. Claim `workflow_step:<step id>` for 30 seconds with the acting user's name. If the claim is already held, return `{:error, :just_done}` and reply `*<step>* was acted on from Slack[ by <holder>] a moment ago, so it was left alone.`
7. Carry out the action with the existing workflow functions: approve the step as the user; retry the step for the deployment group as the user; or skip the step as the user. If the state changed since it was read, surface the existing retry/skip errors.
8. Audit the action with the same description the deployment group page uses, with the action word `approved`, `retried` or `skipped`, but from Slack append ` from Slack user <slack_user_id> (@<slack_username>, workspace <team_id>)`. If there is no Slack username, leave out the `(@..., ...)` portion.
9. Broadcast `"deployments/update"` on the deployment group's existing topic so the orchestrator carries on. Approving or skipping should not complete or start the next step itself.
10. Post in the clicked message's thread with the existing announcement fallback. The text is `":white_check_mark: <user> approved *<step>* for *<group>* from Slack. The rollout carries on."` for approve, and the analogous retried/skipped wording for the others. If the channel/message timestamp is missing, fall back to the private reply.

Routing from Slack interactions must also be added: when `NervesHubWeb.Integrations.Slack.Actions.handle_interaction/1` receives a block action whose id starts with `workflow_step.`, turn it into a `WorkflowSteps` click and run `perform/1` in the background. Return `:ok` immediately, as with the existing device actions. Ignore clicks that `click/2` rejects.

Keep the existing device Slack buttons, device authorization messages, and product notification messages unchanged. Preserve the existing dashboard audit text for approving, retrying and skipping workflow steps; only the Slack path adds the `from Slack ...` suffix. Existing one-argument workflow failure calls must continue to work, and existing event subscriptions must keep receiving the events they already have.
