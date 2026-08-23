-- Extension named pickup groups (named_call_group / named_pickup_group).
-- CREATE TABLE paths already include named_groups (sqlite_create_tenant.sql /
-- full_schema.sql). This file is for apt upgrade of older nodes.
--
-- SQLite has no ADD COLUMN IF NOT EXISTS. postinst applies via
-- apply-sqlite-add-named-groups.sh (PRAGMA check then ALTER). Safe to re-run.
--
-- Default ALL = whole tenant until operator sets department/digit tokens.
-- GenAst: ALL or empty → emit $clst (tenant-scoped); never emit numeric call_group.

ALTER TABLE ipphone ADD COLUMN named_groups TEXT DEFAULT 'ALL';
