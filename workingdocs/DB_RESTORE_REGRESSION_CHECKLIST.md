# DB restore regression checklist

Use this checklist on release-candidate builds to detect backup/restore and DB rebuild regressions.

## Preconditions

- Installed build under test (pbx3 + pbx3api).
- API/UI reachable.
- At least one extension or other tenant row exists to use as a test record.

## Test steps

1. Create **backup A** from the UI or API.
2. Pick a known row (for example an extension), then delete it.
3. Run **Save + Commit** so the deletion is applied to generated runtime config.
4. Restore **backup A** with **restoredb** selected.
5. Verify the deleted row is present again:
   - in the UI/API response, and
   - in `/opt/pbx3/db/sqlite.db`.
6. Check restore logs and confirm:
   - backup filename was resolved from the route path,
   - DB copy step executed,
   - no DB rebuild script was invoked during restore.
7. Run `/opt/pbx3/scripts/reloader.sh` once.
8. Verify reloader behavior:
   - dumper runs before DB delete/rebuild,
   - `/opt/pbx3/db/db_database_dumps/last_data.sql` is produced,
   - customer rows remain present after rebuild.
9. Run **Commit** again and verify generation/reload completes and system behavior is normal.

## Pass criteria

- Restored backup brings deleted data back.
- Reloader preserves customer data across rebuild.
- Commit/generation path still works after restore and rebuild.
