-- Solo inbound DID normalize: trunks.inbound_transform (carrier face → +E.164 before Ingress).
-- Fresh creates: sqlite_create_instance.sql. Existing DBs: apply-sqlite-add-inbound-transform.sh
-- SQLite has no ADD COLUMN IF NOT EXISTS — apply script uses PRAGMA.

ALTER TABLE trunks ADD COLUMN inbound_transform TEXT;
