We have two soft-delete gaps to close. Deleting an org leaves its memberships in place, and deleting a device leaves the device row available so it can be restored. Both still look active to a lot of code that reaches them through a user's membership. Here's the behaviour we settled on.

**Deleted orgs grant no role**

`NervesHub.Accounts.has_org_role?/3` must return false for any role when the org is soft-deleted, even if the user's membership row is still present and not deleted. The membership itself must stay put — `NervesHub.Accounts.get_org_user/2` should still return the `OrgUser` for a deleted org — and removing a member must still make the check false. Keep the usual role hierarchy: a `:manage` member satisfies `:view` and `:manage` but not `:admin`. The database is authoritative here: a caller may hand in an `Org` struct that was loaded before the deletion and still says the org is active; the answer must still reflect that the org is now deleted. Because role checks are what gate the API, requests aimed at a deleted org must fail as not found/unauthorised (404), on both `/api/devices/{identifier}` and the nested `/api/orgs/{org}/products/{product}/devices/{identifier}` forms.

**Lookups must skip devices in deleted orgs**

When a device is looked up by identifier through a user's org membership, or devices are looked up by id through a user's org membership, devices belonging to a soft-deleted org must not come back. `NervesHub.Devices.get_by_identifier/2` should return `{:error, :not_found}` and `NervesHub.Devices.get_devices_by_id/2` should return `[]` once the device's org has been soft-deleted. This has to hold even when the scope was built before the deletion, so the org's current state in the database decides. `NervesHub.Devices.Pinning.get_pinned_devices/1` must likewise leave out pins whose device is in a soft-deleted org; the pin rows can stay, but the list should come back empty.

This is about the org being deleted, not the device: a soft-deleted device in a live org must still be findable so it can be shown and restored.

**Soft-deleted devices are read-only through the API**

A soft-deleted device can still be fetched and shown; the show response keeps the existing `deleted` field set to `true`. `NervesHub.Devices.restore_device/1` still works, and once restored the device behaves normally again (a reboot returns 204). But until then, any action that reaches the device must be refused: reboot, reconnect, upgrade, code, penalty (the DELETE `/penalty` action), and sending a support script (`/scripts/{id}`). This must hold on both the short device URL and the nested org/product device URL. The move action is not one of these; it doesn't reach the device and is already gated by its own role check.

Refuse with status 422 and exactly this body:

```json
{"errors": {"detail": "Device is deleted and must be restored to use."}}
```

The refusal must happen before anything is sent to the device: no broadcast goes out on the device or device-socket channels, and no support script is run.

Update the OpenAPI response documentation for those actions to include the 422 error alongside the existing 204/404 responses.

Existing deletion and restoration behaviour is otherwise unchanged; the dashboard already refuses changes to a deleted device through the changeset, and that stays as it is.

The names the rest of the code uses, unchanged: `NervesHub.Accounts.has_org_role?/3`, `NervesHub.Accounts.get_org_user/2`, `NervesHub.Accounts.soft_delete_org/1`, `NervesHub.Devices.get_by_identifier/2`, `NervesHub.Devices.get_devices_by_id/2`, `NervesHub.Devices.delete_device/1`, `NervesHub.Devices.restore_device/1`, `NervesHub.Devices.Pinning.get_pinned_devices/1`.
