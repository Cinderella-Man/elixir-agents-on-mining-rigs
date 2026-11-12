Add a read-only device metric history API.

Expose it as two GET endpoints:

- `/api/devices/:identifier/metrics`
- `/api/orgs/:org_name/products/:product_name/devices/:identifier/metrics`

Wire both as action `:index` in the existing API scopes so `Routes.api_device_metric_path` supports the short form `(conn, :index, identifier, params)` and the product-scoped form `(conn, :index, org_name, product_name, identifier, params)`. Use the same organization `:view` authorization as the other device read endpoints. A user outside the device’s organization must get the existing 404 authorization error.

The response for a successful request is `200` with:

`{"data": [ ... ]}`

Each entry is one report:

- `timestamp`: the stored report time as an ISO 8601 string, preserving the stored value and parseable by `DateTime.from_iso8601/1`
- `firmware_uuid`: the firmware UUID the device was running, or `null` when none was reported; an empty stored value should come back as `null`
- `metrics`: an object mapping metric names to numeric values

A report is all readings taken at the same timestamp, not one entry per reading. A device with no stored reports returns `{"data": []}`. Only the requested device’s reports must be returned, never another device’s.

Supported query parameters are:

- `key`: comma-separated metric names. Trim whitespace around each name, drop empty names, and if no names remain treat it as no filter. Several names mean only those readings are returned. A report that carried none of the requested metrics is omitted. Unknown metric names are valid filters and simply match nothing; do not validate them against a list. Matching is exact; no wildcards, prefixes or case folding.
- `since`: ISO 8601 timestamp, inclusive lower bound.
- `before`: ISO 8601 timestamp, exclusive upper bound. Passing the timestamp of the oldest report already received must page to older reports without repeating that report.
- `limit`: number of reports, default `100`, allowed values `1` through `1000`. It counts reports, not readings, and applies after the key/time filters. A limit of 1 for a report with several readings must return that whole report.
- `order`: `desc` for newest first, which is also the default when missing or empty, or `asc` for oldest first.

Missing or empty `since`, `before` and `order` mean no bound/default behaviour. Empty `limit` uses the default.

Invalid query values must produce `422` using the existing API error shape, with `errors.detail` containing the relevant text:

- invalid `since`/`before` timestamps: detail containing `since must be an ISO 8601 timestamp` or the corresponding `before` wording
- invalid `limit`: detail containing `limit must be a whole number between 1 and 1000`
- invalid `order`: detail containing `order must be asc or desc`

If `Application.get_env(:nerves_hub, :analytics_enabled)` is false, do not answer with an empty list. Return `501` using the existing API error shape, with `errors.detail` containing `device metric history is not stored`. Check this before reading history or validating ordinary query parameters.

Include both endpoints in the generated OpenAPI documentation with their query parameters and the report-list response shape. The API is read-only: do not add a way to write, delete or aggregate metric readings through it, and do not change metric ingestion or retention. There is only the stored analytics history to expose, currently retained for thirty days.
