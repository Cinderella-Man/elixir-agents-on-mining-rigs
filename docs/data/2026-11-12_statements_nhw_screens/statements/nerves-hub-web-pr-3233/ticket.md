Archives currently all share the upload path `/archives/<uuid>.fw`. Two orgs can build archives with the same UUID, so one upload can overwrite the other and deleting either archive can remove the other's file. We need to scope new archive files by org and product while keeping old archives working.

**Data model**

`NervesHub.Archives.Archive` gets a nullable `storage_key` string field, which is the full upload path for the archive's file. New archives have a non-nil key; archives uploaded before this feature have `nil`. The database column should be nullable, and `storage_key` should be unique. Keep the existing archive constraints, including the existing product/UUID uniqueness.

**New archives**

For a new archive, `storage_key` must be `/archives/<product.org_id>/<product.id>/<uuid>.fw`, using the numeric product org ID, numeric product ID, and the archive's UUID. For example, if the product belongs to org ID 12 and has product ID 34, and the archive UUID is `550e8400-e29b-41d4-a716-446655440000`, the key is `/archives/12/34/550e8400-e29b-41d4-a716-446655440000.fw`. The UUID is the one parsed from the archive file, not something chosen by the server.

The file is uploaded to that exact path. `archive.storage_key` must be set to it, and URLs/download redirects for the archive must point at `/uploads` plus that storage key. When an archive is deleted, the delete job's `archive_path` argument must be the archive's `storage_key` for new archives.

This means two products, or two orgs, can each upload an archive with the same UUID without sharing a file. Deleting one must not affect the other, even if both archives have the same UUID. Uploading the same UUID again in the same product uses the same storage path as before; if the old archive row has been deleted but its old file-deletion job has not run yet, the new archive still owns that file and the old job must leave it in place.

**Archives from before this change**

Do not move or rewrite any existing files. An archive with `nil` `storage_key` continues to use the old path `/archives/<uuid>.fw` for storage, URL, download redirect, and deletion. Its delete job must receive that legacy path in `archive_path`. No new archive should ever be written to the legacy path.

Because old archives were not scoped by org or product, multiple old archives with the same UUID share the legacy file. The legacy file may only be deleted when no archive still refers to it. That means a delete job for `/archives/<uuid>.fw` must keep the file if any archive with `nil` `storage_key` and that UUID still exists; only the final deletion of those archives should remove it. Likewise, a new archive in another org with the same UUID gets its own storage key and must never overwrite or take the legacy file. The old path form is exactly `/archives/<uuid>.fw`; only that exact old form should be treated as the legacy UUID path.

**Deleting files**

The `DeleteArchive` worker already receives `archive_path`. It should only delete the file at that path when no archive still uses that path. For a normal storage key, that means no archive has the same `storage_key`. For a legacy `/archives/<uuid>.fw` path, that also means no archive with `nil` `storage_key` has that UUID. If any archive still refers to the path, the job should succeed without deleting anything.

This check must happen when the delete job runs, not when the archive row is deleted, so an archive deleted and uploaded again before its old deletion job runs keeps its file. A file is only deleted once no archive uses its path.

**Compatibility and scope**

Old archives must keep working exactly as before apart from the deletion protection: same URL, same download redirect, same deletion path. There is no backfill, no moving of old files, and no rewriting of old rows to the new path. New uploads always use the scoped path. The download URL/redirect behavior must use the effective path, so new archives redirect to `/uploads/archives/<org id>/<product id>/<uuid>.fw` and old archives redirect to `/uploads/archives/<uuid>.fw`.
