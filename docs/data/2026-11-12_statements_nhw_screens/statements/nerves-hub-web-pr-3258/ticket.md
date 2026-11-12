We need to align several authorization checks so that org `manage` is enough for these write and download actions, while `view` remains read-only.

Product API
- Creating, updating, and deleting products must require the org `manage` role. Admins continue to be allowed.
- Listing and showing products stay at `view`.
- Keep the existing API success/error response shapes; this is only an authorization change.

Certificate authorities
- Creating, updating, and deleting certificate authorities must require `manage`, not the stricter admin-only check.
- This applies to both the API and the org certificate-authorities settings UI.
- A `view` member must not be offered the Delete action; if that action is forced directly, it must be rejected through the existing unauthorized path (`NervesHubWeb.UnauthorizedError`) and the certificate must remain.
- A `manage` member can delete a CA and gets the existing success behavior.
- CA creation must still require the existing proof-of-private-key / verification certificate checks; do not weaken certificate validation.
- API unauthorized create/delete should keep returning the existing 401 authorization error, and successful delete keeps 204.

Firmware downloads
- Downloading a firmware image in the browser requires `manage`, same as firmware upload/delete. A `view` member can still open the firmware detail page, but must not see a Download link/button.
- A direct GET to the firmware download route by a `view` member must return the existing 401 authorization response.
- The firmware detail page’s Download control must be rendered only when the current scope is allowed to download. Deleted firmware still offers no download.
- Archive downloads remain available at `view`; do not tighten those.

Keep all other existing product, firmware, and certificate-authority permissions and behavior unchanged; this should only change the role level required for the actions above.
