Add a product archives API under the existing org/product API routes. The routes must generate the helper `api_archive_path` with these actions:

- GET `/api/orgs/:org_name/products/:product_name/archives` — list archives for the product
- POST `/api/orgs/:org_name/products/:product_name/archives` — upload an archive
- GET `/api/orgs/:org_name/products/:product_name/archives/:uuid` — show one archive
- GET `/api/orgs/:org_name/products/:product_name/archives/:uuid/download` — redirect to the archive download

List and show need org `:view` access; upload and download need org `:manage` access. A `:view` user attempting upload or download must get the existing 401 authorization response. A user from another org trying to download must get a 404. Archives are always looked up in the path product, so an archive that belongs to a different product in the same org is not found (404), even if the UUID exists.

The JSON response shape should use a `data` key. List returns `%{"data" => [...]}`; show and successful create return `%{"data" => %{...}}`. Each archive object must include:

`uuid`, `version`, `platform`, `architecture`, `author`, `description`, `misc`, `vcs_identifier`, `size`, and `inserted_at`.

`size` is an integer byte count. Nullable text fields may be `nil`. An empty archive list must be `%{"data" => []}`.

Upload accepts a multipart request whose file part is named `archive`; the filename itself does not matter. On success return 201, include a `Location` header pointing at the archive show URL, and return the created archive. The archive must be associated with the org signing key that signed it, and the returned UUID must be usable with the existing archives lookup for that product.

Upload validation:

- The file must be an fwup archive signed by an Ed25519 key registered to the organization.
- If the organization has no signing keys, return 422 with `errors.detail` exactly: `This organization has no signing keys. Register one before uploading.`
- If the signature does not match any org key, or the file is corrupt, return 422 with `errors.detail` exactly: `The signature does not match any of this organization's signing keys, or the file is corrupt.`
- If the file is not a readable fwup archive, return 422 with `errors.detail` exactly: `The file is not a readable fwup archive.`
- If required metadata is missing, return 422 with `errors.detail` exactly: `The file's metadata must include meta-product, meta-platform, meta-architecture and meta-version.`
- The metadata version must be valid SemVer. Accept versions such as `1.2.0+build.5`. Reject versions such as `release-1.2` with a 422 changeset error under `errors.version`.
- A request with no `archive` part should be rejected as an upload error rather than crashing.

Archive uploads must not be limited by the default request size. The archive upload route needs the same runtime-configurable large-file handling used for firmware uploads, with its own archive upload limit. At minimum, a 2 MB upload made of arbitrary bytes must get through request parsing and be handled by archive validation; it should return the invalid-signature 422 response rather than a request-too-large response. Existing firmware upload behavior must remain unchanged.

Download must redirect externally to the archive URL, which includes `archives/<uuid>.fw`. Show and download must return the existing 404 JSON error when the archive is not found for the path product.

The API fallback must also handle these error tuples with status 422 and the same reason strings:

- `{:error, :invalid_signature}`
- `{:error, :no_public_keys}`
- `{:error, :invalid_fwup_file}`
- `{:error, :invalid_metadata}`

Use the existing JSON error envelope, with the reason under `errors.detail`.

The generated API documentation should include an archives tag and document these endpoints, including the list, single archive, upload, upload error, and not-found responses.
