We need deleting a device to put it into a genuinely inactive state. It should still be a soft delete, but a deleted device must not remain in a deployment group or stay connected, because the orchestrator can still select it and cannot penalty box it.

When `delete_device/1` succeeds:
- Keep the existing soft-delete and cleanup behavior, including setting `deleted_at` and removing associated certificates, pinned-device entries and network identities.
- Clear the device’s `deployment_id` as part of the same deletion transaction. The returned device must have a non-nil `deleted_at` and `deployment_id == nil`, and reloading it from the database must show the same.
- The device must stop being included by `Updates.available_for_update(deployment_group, 10)` for its former deployment group.
- Only after the deletion commits successfully, tell `"device_socket:#{device.id}"` to disconnect with event `"disconnect"`. A connected device should transition to offline and no longer be considered online/available.
- Preserve the current return shape: `{:ok, device}` on success. If the delete fails, return the existing error and do not disconnect the device.
- Deleting a device with no deployment group or no open connection should still work; clearing the deployment group is a no-op in that case.

Once a device is deleted, connection attempts must be refused. This includes a retry using the same shared-secret authentication and signature that was valid before deletion and is still within its allowed age. The handshake should not be accepted and then left connected. Deleted devices must not come back online or become selectable again. Also do not allow a new device to be created under the same identifier via a product key. This refusal should apply consistently whether the device would authenticate by certificate, device key or shared secret.

`restore_device/1` must remain the undo path for a soft-deleted device. Do not restore the old deployment group as part of restore; a restored device has no deployment group until it next connects and is matched as any other unassigned device.

Update the confirmation prompt on the existing device delete button so it explains the new effects. Use: “Are you sure you want to delete this device? It will be disconnected and removed from its deployment group, and any certificates associated with it will be deleted.”

Everything else about device deletion should stay compatible: no hard deletion, no change to event/history cleanup beyond the existing behavior, and non-deleted devices must continue to work exactly as before.
