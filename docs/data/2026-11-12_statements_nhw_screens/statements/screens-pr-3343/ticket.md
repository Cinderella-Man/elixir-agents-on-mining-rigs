Add an alert-linked evergreen cleanup to the admin maintenance API and the admin tools page.

Backend behavior:
- Add public `Screens.Util.Admin.expired_alert_content_cleanup_updates/1`, taking a list of `%Screens.Config.ScreenConfig{}` and returning `{:ok, updates}` or `:error`. Each update is `%{id: screen_id, config: cleaned_screen_config}`. Include only screens whose config actually changes, and return `{:ok, []}` when nothing changes.
- For each screen, inspect `config.app_params.evergreen_content`. Only items with `%ScreensConfig.AlertSchedule{alert_ids: ids}` and at least one ID are candidates. Remove an item only if none of its linked alert IDs are present in the current alerts feed. Keep it if at least one linked alert is still present. Keep items with empty alert ID lists, scheduled evergreen items, and screens without evergreen content untouched. Preserve all other config fields and the order of retained items.
- Collect the unique referenced alert IDs across all passed configs and fetch the current alerts once. If there are no referenced IDs, do not perform an alert fetch and return `{:ok, []}`. If the alert lookup fails, return `:error` and produce no updates.
- The alert lookup returns current alert IDs; compare against the string IDs stored in the configs.

Controller:
- Add action `"alert_content_cleanup"` to the existing `/api/admin/maintenance` endpoint.
- When the request includes `dry_run`, use all stored screen configs, compute the updates, and return 200 with `%{screen_ids: [...]}`. The IDs must be sorted and include every screen that would change. Dry run must not persist anything or invalidate cached screen data.
- On an alert lookup error during dry run, return 502 with `%{success: false, error: "Failed to fetch alerts from the V3 API"}`.
- Without `dry_run`, accept a list under `screen_ids`, look up only those configs by ID, compute the same updates, and persist them through the existing bulk config update path. Return 200 with `%{success: true, updated: count}`, where `count` is the number of changed configs. Persist only changed configs. Cache invalidation must be triggered for exactly the changed screen IDs before the response.
- If the alert lookup fails during apply, return the same 502 error and leave the configs untouched. If persistence fails, return 500 with `%{success: false, error: ...}`. Do not change the behavior of existing maintenance actions.

Admin tools page:
- Put the existing evergreen cleanup and the new alert cleanup under an `Evergreen Content Cleanup` section. Rename the existing subsection heading to `Schedule-Based Content Cleanup` and keep its current form behavior.
- Add an `Alert-Linked Content Cleanup` subsection with a short explanation and a Cleanup button. The button must be disabled while a request is in flight, and duplicate submits must be ignored.
- On submit, first request `action: "alert_content_cleanup"` with `dry_run: true`. If the response is not 200, show an error alert and stop. If `screen_ids` is empty, show `No screens would be affected.` and stop. Otherwise confirm with the user that this affects the reported number of screens. If cancelled, stop. If confirmed, request `action: "alert_content_cleanup"` with the returned `screen_ids`. Show `Configuration updated.` on 200, or show the server error on failure.
- Use the existing admin API helper used by the other tools.
- Give top-level tool sections visible separation with extra top margin and a top rule.
