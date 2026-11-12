Wayfinding information on departures headers currently ignores its schedule. Make it schedule-aware so the image and the spoken readout only appear while a schedule window applies.

Add `Screens.V2.WidgetInstance.Utils.in_schedule_windows?/2`, taking a list of `ScreensConfig.Schedule` and a `DateTime`, returning a boolean. It should return false for an empty list and true if any schedule item matches `now` using these rules:

- `start_dt: nil, end_dt: nil` always matches.
- `start_dt: nil, end_dt: end` matches only when `now < end`.
- `start_dt: start, end_dt: nil` matches when `now >= start`.
- `start_dt: start, end_dt: end` matches when `start <= now < end`.

So start is inclusive and end is exclusive.

For `Screens.V2.WidgetInstance.Departures.serialize_section/3` and `/4`, when a header has wayfinding information with `image_path`, keep the existing S3 URL conversion only if the wayfinding schedule applies at the section’s `now`. If the schedule is empty or does not apply, serialize `wayfinding_information.image_path` as `nil` while keeping the rest of the wayfinding information, including the schedule, in the header. This must be true for normal, no-service, and overnight sections; the `now` argument passed to the no-service and overnight serializers must now be used.

For `Screens.V2.WidgetInstance.Departures.audio_serialize_section/3`, set `wayfinding_readout` to the configured `read_as` string only when the wayfinding schedule applies at `now`. If the schedule is empty or does not apply, `wayfinding_readout` should be `nil`. This applies to normal, no-service, and overnight sections. If there is no `read_as`, it should remain `nil`.

`Screens.V2.WidgetInstance.EvergreenContent.valid_candidate?/1` should keep exactly its current schedule semantics, but use the shared `in_schedule_windows?/2` helper so both places agree.

Existing output when a schedule window does apply should stay the same: the same S3 URL is serialized and the same `read_as` value is read aloud. Headers with no wayfinding information must serialize as before. Do not change schedule configuration, schema, or any rendering outside this wayfinding gating.
