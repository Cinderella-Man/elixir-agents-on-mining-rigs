fwup metadata parsing drops values that contain an equals sign: a firmware with `meta-misc = "e=mc^2"` comes back with `misc` nil instead of `e=mc^2`, and following metadata should still parse. It should keep everything after the first equals sign as the value.

Also the firmware API JSON is missing several existing fields. Firmware responses should include `description`, `misc`, `vcs_identifier`, `size` in bytes, and `inserted_at`, and the API schema/examples should document them as nullable where appropriate.
