-- S7 tenant opt-in: cluster.rec_s3 YES/NO (default NO).
-- Fresh creates: sqlite_create_tenant.sql. Existing DBs: apply-sqlite-add-rec-s3.sh
-- SQLite has no ADD COLUMN IF NOT EXISTS — apply script uses PRAGMA.

ALTER TABLE cluster ADD COLUMN rec_s3 TEXT DEFAULT 'NO';
