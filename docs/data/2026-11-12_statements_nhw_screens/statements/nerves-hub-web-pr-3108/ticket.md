Please add shared secrets that belong to individual devices, for provisioning a unique credential per device. Leave the existing product-level `nhp_` shared-secret registration, certificate authentication, and ordinary device creation alone except where noted below.

Everything here is gated by `NervesHub.DeviceLink.shared_secrets_enabled?/0`. When it returns false, `Devices.issue_shared_secret_auth/2` and `Devices.create_device_with_shared_secret_auth/2` return `{:error, :shared_secrets_not_enabled}` and write nothing; the device settings section stays hidden; the API create paths return 422; and device creation with `shared_secret` does not create the device.

## Data and credentials

- Add `last_used` as a UTC datetime, `created_by_id`, and a `belongs_to` association named `deactivated_by` pointing at `NervesHub.Accounts.User`. Existing records may have no creator or deactivator. User references must restrict hard deletion so attribution cannot be lost; soft-deleted users must still appear in the UI.
- Add indexes on the device foreign key and both user foreign keys.
- `secret` must be marked so `inspect/1` never prints it.
- New keys use the `nhd_` prefix plus 43 URL-safe characters from `[A-Za-z0-9_-]`, so they can be used as one URL path segment. New secrets keep the existing standard Base64 alphabet and format. Keys created before this change, including those containing `/` and `+`, must still authenticate and must still be deactivatable when URL-encoded.
- Creation and deactivation audit the current user with these exact descriptions:
  - `"User #{user.name} created shared secret #{auth.key} for device #{device.identifier}"`
  - `"User #{user.name} deactivated shared secret #{auth.key} for device #{device.identifier}"`

## Device functions

`Devices.create_shared_secret_auth/1,2` keeps creating a key without auditing and accepts `created_by_id`.

`Devices.issue_shared_secret_auth/2` first checks the feature gate, then creates the secret with the issuing user as `created_by_id` and audits it. It returns `{:ok, auth}` or the errors described above.

`Devices.list_shared_secret_auths/1` returns every key the device has been given, deactivated ones included, oldest first by id. `secret` must come back as `nil`; the list must never contain or load the secret. `created_by` and `deactivated_by` must be preloaded.

`Devices.mark_last_used/1` records use of a device-owned key at most once every 15 minutes. If `last_used` is nil or older than the cutoff, update it to the current second-precision UTC time; otherwise skip the write. It must return `:ok` and must not change the record’s `updated_at`. Product shared-secret authentication must not call this.

`Devices.deactivate_shared_secret_auth/3` performs one atomic update for a key that belongs to that device and is still active. It sets `deactivated_at` and the deactivating user. Return `{:ok, auth}` with the updated timestamp and deactivated-by user available. For an unknown key, an already deactivated key, or another device’s key, return `{:error, :not_found}`, write nothing, create no audit, and broadcast nothing. After success, `Devices.get_shared_secret_auth/1` must return `{:error, :not_found}` for that key. Audit the deactivation, then after the transaction commits broadcast a `"disconnect"` event only on `NervesHub.DeviceEvents.shared_secret_topic(key)`, which returns `"shared_secret:" <> key`. Do not broadcast on the device socket topic.

`Devices.create_device_with_shared_secret_auth/2` creates the device and its shared secret in one transaction and returns `{:ok, {device, auth}}`. If the device cannot be created, no secret is created. If the secret cannot be created, for example because the user row does not exist, the device insert must roll back and the error must be the changeset with the `created_by_id` error. If the feature is disabled, no device is created.

## Authentication and sockets

When the existing device-link authentication succeeds with a device-owned key, record its use through `Devices.mark_last_used/1`. Deactivated keys must not authenticate.

A websocket authenticating with a device-owned key must be listening for that key’s deactivation before authentication is accepted, so deactivation during authentication cannot leave a live connection behind. If authentication fails, stop listening. Deactivating a key closes only connections made with that key; connections using a certificate or another key stay up. The existing device socket topic is not used for this per-key disconnect.

## Device settings tab

Show a `#shared-secrets` section only when the feature is enabled.

The section lists every key, including deactivated ones. Each row shows the key, and either `"Never used"` or `"Last used"` with the relative time. Show who created it with tooltip text `"Created by <name>"` and, when deactivated, who deactivated it with `"Deactivated by <name>"`, even after that user is soft deleted. An empty list shows `"No shared secrets have been created."`.

When there are no keys and the user has `device:update` authorization on a non-deleted device, show a `"Create shared secret"` button. Creating one shows a one-time reveal: a warning instructing the user to copy the secret at once because it will not be shown again, the key in a code block, a hidden input with `id="shared-secret-new"` containing the secret, a `"Copy secret"` button, and a `"Done"` button. `"Done"` removes the reveal; the key remains in the list, and a refresh must not show the secret again. Listing must never render a stored secret.

For an active, non-deleted device, authorized users get a `"Deactivate"` button per active key. Deactivation refreshes the list, shows the flash `"The shared secret has been deactivated, and connections made with it closed."`, and replaces the button with a `"Deactivated"` marker. View-only members see keys but no create or deactivate buttons. A deleted device is read-only here.

## Device creation API

The existing device-create endpoint accepts `shared_secret`. When it casts to true, including `true`, `"true"`, and `"1"`, create the device and its own shared secret in the same transaction, audit it with the current user, and return the normal 201 response with an extra `data.shared_secret` object. That object contains `key`, `secret`, `deactivated_at`, `last_used`, and `inserted_at`; this is the only response where the secret is returned. A later show response must not include `shared_secret`.

When `shared_secret` is absent, false, `"false"`, `"0"`, or null, behavior stays as it is now and no secret is created. The endpoint uses the same boolean casting behavior as the device’s other boolean fields. Any value that does not cast, such as `"on"`, returns 422 with exactly:

`shared_secret must be true or false, got "on".`

under `errors.detail`, and no device is created. A duplicate identifier returns 422 and creates no second secret. If the feature is disabled, the 422 reason is the platform-not-enabled message described above and no device is created.

## Shared-secret API endpoints

Add these routes under the existing device path:

- `GET /api/orgs/:org_name/products/:product_name/devices/:identifier/shared_secrets` — view role. Returns 200 with `data` as an array of objects containing `key`, `deactivated_at`, `last_used`, and `inserted_at`. Do not include `id` or `secret`.
- `POST /api/orgs/:org_name/products/:product_name/devices/:identifier/shared_secrets` — manage role. Returns 201 with `data` containing `key`, `secret`, `deactivated_at`, `last_used`, and `inserted_at`. The secret appears only here.
- `DELETE /api/orgs/:org_name/products/:product_name/devices/:identifier/shared_secrets/:key` — manage role. Returns 204 with an empty body on success. Return 404 for an unknown, already deactivated, or other device’s key. Accept an encoded key path segment so old keys containing `/` and `+` work. Return 422 for a deleted device with `"Device is deleted and must be restored to use."`

Creation and deletion on a deleted device are refused before doing any work. Document the new endpoints and the create-time `shared_secret` boolean in the API spec.
