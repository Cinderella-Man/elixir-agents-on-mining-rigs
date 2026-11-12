We need firmware and archive uploads to distinguish "this image requires a newer fwup" from "invalid signature". Right now both come back as invalid signature, which sends people to check keys instead of realizing NervesHub's fwup is too old.

When fwup rejects an image because it requires a newer version, return an error tagged :fwup_too_old carrying the required version and the locally installed fwup version, both as strings, for example required "99.0.0" and installed "1.17.1". This should come out of NervesHub.Firmwares.verify_signature/2 and NervesHub.Archives.create/2. The installed value should be the actual fwup version in its normal major.minor.patch form, not a label. If fwup is too old, report that immediately rather than continuing to try other public keys; it is not a per-key signature problem. Keep :invalid_signature for actual signature mismatches and other fwup failures.

NervesHub.Archives.create/2 should also return :no_public_keys when the organization has no keys configured, before trying metadata. That case must not look like an invalid signature.

For the API firmware upload route, when this happens return 422 Unprocessable Entity with errors.detail set to: "This firmware requires fwup <required> or newer, and NervesHub has fwup <installed>. Please contact support to have NervesHub's fwup updated." and do not create the firmware record.

On the firmware live upload page, show the same message in the upload error area. On the archives live upload page, show the analogous message: "This archive requires fwup <required> or newer, and NervesHub has fwup <installed>. Please contact support to have NervesHub's fwup updated."

All the existing invalid-signature, no-keys, product-mismatch, and archive error handling should keep working unchanged. The fwup binary installed for CI and the Docker image needs to be 1.17.1 (we are on 1.16.0 now); older fwup will not understand the required-version metadata, so this will just look like a bad signature.

Example: a signed firmware that requires fwup 99.0.0 uploaded to a NervesHub running fwup 1.17.1 should produce the version error, and the message should not mention signatures or keys.
