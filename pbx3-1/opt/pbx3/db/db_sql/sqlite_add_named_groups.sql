-- Extension named call / pickup groups (split fields).
-- CREATE TABLE paths already include named_call_group + named_pickup_group
-- (sqlite_create_tenant.sql / full_schema.sql). This file documents the upgrade
-- path; postinst applies via apply-sqlite-add-named-groups.sh (PRAGMA check then
-- ALTER). Safe to re-run via that script only — raw ALTER is not idempotent.
--
-- Default ALL = whole tenant until operator sets department/digit tokens.
-- GenAst: ALL or empty → emit $clst (tenant-scoped); never emit numeric call_group.
--
-- Legacy single column named_groups (2026-08-23) is copied into both new columns
-- by the apply script, then left in place (SQLite cannot DROP COLUMN cheaply).

ALTER TABLE ipphone ADD COLUMN named_call_group TEXT DEFAULT 'ALL';
ALTER TABLE ipphone ADD COLUMN named_pickup_group TEXT DEFAULT 'ALL';
