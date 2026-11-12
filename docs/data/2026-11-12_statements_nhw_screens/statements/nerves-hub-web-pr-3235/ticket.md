We need to make deleting a product or an org a real disconnect for its devices, and keep JITP from provisioning into deleted products.

Product/org deletion:
- `NervesHub.Products.delete_product/1` should keep its existing return contract. After a successful soft delete, broadcast a disconnect for every device in that product whose latest connection is currently connected. Use the existing device socket topic `"device_socket:<device_id>"` and event `"disconnect"` with an empty payload. Do not disconnect devices in other products.
- `NervesHub.Accounts.soft_delete_org/1` should continue to soft-delete the org and all its products with the existing transaction and timestamp behavior, and return the existing `{:ok, org}` / `{:error, changeset}` shapes. Only after a successful delete, close connections for all connected devices in every product of that org. This must not touch devices in other orgs, and devices whose latest connection is not connected are not sent a disconnect.
- `NervesHub.Accounts.remove_account/1` should keep its existing account-removal behavior, including the orgs it removes because the user was the last member and the products/devices it already deletes. After success, close connections for connected devices in the products of the orgs that were removed. Any org that survives because another user remains must be untouched. Do not send disconnects for unrelated orgs/products.
- Deleting an org with its products leaves devices, device certificates and device keys in place; do not soft-delete or change device registration/status as part of org or product deletion. Product deletion also leaves devices and certificates alone; they simply cannot connect through a deleted product. If deletion fails, keep the existing error return and do not send any disconnect messages.

Device authentication:
- `NervesHub.DeviceLink.Authentication.authenticate/2` must return `{:error, :invalid_auth}` when the identified device itself is soft-deleted, or when its product is soft-deleted. This applies whether authentication uses a device certificate, a device shared secret, or a product shared secret; the fact that the certificate/key still exists must not let it through. An org deletion is covered by its products being deleted.
- For these refusals, emit the existing `[:nerves_hub, :devices, :invalid_auth]` telemetry event with `reason: :deleted`, and include `org_id`, `product_id` and `identifier` for the identified device. Keep the existing checks and hostname behavior for non-deleted devices, and do not stop a device in another product of the same org from authenticating when only one product was deleted.
- A deleted device with a still-present certificate must be refused on its own deleted state, too.

JITP/SSL:
- When a CA certificate's JITP setup points at a soft-deleted product, do not create a device during verification. Return the ignored deleted-product failure as the product counterpart of the existing ignored deleted-device outcome (`:ignore_deleted_device` naming convention), and make sure no device row is created. This includes the case where an org was deleted, since its products are deleted while its CAs remain.
- Non-deleted products and non-JITP verification paths should keep their current behavior.

Keep the existing public names and return shapes above; this is about the delete paths emitting disconnects and authentication/JITP refusing deleted products without changing the stored devices.
