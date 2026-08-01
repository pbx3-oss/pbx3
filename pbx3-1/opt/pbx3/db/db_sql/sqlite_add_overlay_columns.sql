-- GenAst hermit C2/H overlays: thin overlay columns on existing instance DBs.
-- CREATE TABLE paths already include these (sqlite_create_tenant.sql /
-- sqlite_create_instance.sql). This file is for apt upgrade of older nodes.
--
-- SQLite has no ADD COLUMN IF NOT EXISTS. postinst applies via
-- apply-sqlite-add-overlay-columns.sh (PRAGMA check then ALTER). Safe to re-run.
--
-- Tables / columns:
--   ipphone.pjsip_overlay   TEXT  -- phone / WebRTC PJSIP key merge
--   trunks.pjsip_overlay    TEXT  -- trunk PJSIP key merge
--   queue.queue_overlay     TEXT  -- queue.conf flat KV merge
--   cluster.park_overlay    TEXT  -- parking_lot key merge

ALTER TABLE ipphone ADD COLUMN pjsip_overlay TEXT;
ALTER TABLE trunks ADD COLUMN pjsip_overlay TEXT;
ALTER TABLE queue ADD COLUMN queue_overlay TEXT;
ALTER TABLE cluster ADD COLUMN park_overlay TEXT;
