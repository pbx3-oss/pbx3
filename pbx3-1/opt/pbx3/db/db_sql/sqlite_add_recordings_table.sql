-- Phase R1.5: add recordings catalog table to existing instance DBs.
-- Safe to run multiple times (IF NOT EXISTS).
BEGIN;

CREATE TABLE IF NOT EXISTS recordings (
    "id" TEXT PRIMARY KEY,
    "cluster" TEXT NOT NULL,
    "epoch" INTEGER NOT NULL,
    "callerid" TEXT,
    "dnid" TEXT,
    "queue" TEXT,
    "extension" TEXT,
    "filename" TEXT NOT NULL,
    "local_path" TEXT,
    "s3_key" TEXT,
    "location" TEXT NOT NULL DEFAULT 'spool',
    "filesize" INTEGER,
    "deleted_at" datetime,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "filename")
);
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_epoch ON recordings ("cluster", "epoch");
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_callerid ON recordings ("cluster", "callerid");
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_dnid ON recordings ("cluster", "dnid");

COMMIT;
