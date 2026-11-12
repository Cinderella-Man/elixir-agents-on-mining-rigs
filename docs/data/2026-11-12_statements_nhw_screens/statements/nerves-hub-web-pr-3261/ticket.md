Device update-mode changes need to go through an explicit, atomic path rather than being cast as an ordinary settings field. The update mode has side effects that do not belong in the generic device update: moving to `:automatic` clears update attempts, the change gets its own audit entry, and deployment orchestration must only be told after the change is committed.

Settled behavior:

- `Device.update_changeset/2` should keep casting `description`, `tags` and `connecting_code`, but it must no longer cast `update_mode`. An `update_mode` included in those params should be ignored rather than saved or treated as an error.
- Device creation must keep its existing behavior: `create_changeset/2` still accepts and casts `update_mode`, so an initial mode can be set when a device is created.
- Add `Device.cast_update_mode/2`. It should validate only `update_mode` on its own and return:
  - `{:ok, mode}` when the params contain a valid mode different from the device’s current mode;
  - `{:ok, nil}` when there is no `update_mode` key, or when the requested mode is the same as the current mode;
  - `{:error, changeset}` for an invalid value or an explicit `nil`. The changeset errors must be under `update_mode`: `"is invalid"` for an unknown value and `"can't be blank"` for `nil`.
- `Devices.update_device_settings/4` should accept a new `:update_mode` option. Any `update_mode` inside the normal params map must be ignored. When the option changes the mode, the settings update, the mode save and both audit entries must be in the same transaction. The update-mode audit entry keeps the existing wording, e.g. `User <user> set the update mode for device <identifier> to off`, while the normal settings save keeps its existing wording. If the mode is unchanged or the option is absent/nil, no update-mode audit entry is written and other settings may still be saved normally.
- Applying a changed mode should go through `Updates.save_update_mode/3`, with the user as the actor, and it must clear the device’s update attempts when moving to `:automatic`. `save_update_mode/3` has the same permission and audit behavior as the existing `set_update_mode/3`, but it must not notify the deployment orchestrator itself. It returns `{:ok, device}` or the existing mode-setting error tuples.
- `Devices.update_device_settings/4` must return the final device from the transaction. After the transaction commits, tell `DeploymentOrchestratorEvents.device_updated/1` about a device that actually moved to `:automatic` and has a `deployment_id`; this notification must not happen inside the transaction and must not happen for a move to another mode or when the mode is unchanged. The existing post-commit device-updated notification should still see the fully updated device.
- The existing `Updates.set_update_mode/3` path used by the UI update-mode buttons must keep its current behavior: save and audit, clear attempts when moving to `:automatic`, and notify the orchestrator after the save has committed.
- `Devices.update_device_settings/4`’s existing `:managed_updates_allowed` option must keep working. It can be combined with `:update_mode`; if either write fails, nothing from the request commits and no audit entries remain.

API behavior:

- The existing device update endpoint should accept `update_mode` wherever it accepts the other settable device fields, under the normal device params handling. Use `Device.cast_update_mode/2` before writing anything. An invalid mode or explicit nil must return a 422 response shaped like `%{"errors" => %{"update_mode" => ["is invalid"]}}` or `%{"errors" => %{"update_mode" => ["can't be blank"]}}` and must leave the description, mode and audit log untouched.
- A valid changed mode must be passed to `Devices.update_device_settings/4` as the `:update_mode` option. The response’s device data must show the new mode, e.g. `"automatic"`.
- Moving to `:automatic` through the API must clear update attempts, write the update-mode audit entry, and notify the deployment orchestrator only after commit, with the persisted device. Moving out of automatic or sending the mode already in use must audit no mode change and must not notify the orchestrator. Sending another valid field alongside the same/no mode should still save that field.
- If `Updates.save_update_mode/3` returns an error changeset, the API must return 422 with those `update_mode` errors, roll back the other settings, leave the device unchanged and write no audit entries.
- Keep `update_mode` documented in the API’s create and update request bodies. In the update documentation, describe that a mode change is audited and that a device moved to automatic is considered by its deployment group immediately.

The device settings form should ignore any `update_mode` it posts; changing the mode stays with the existing details-tab controls.
