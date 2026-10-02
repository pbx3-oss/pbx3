-- Customer provision stream fragments (B4). Safe to re-run (IF NOT EXISTS).
BEGIN;

CREATE TABLE IF NOT EXISTS provision_stream (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "cluster" TEXT NOT NULL DEFAULT 'default',
    "body" TEXT NOT NULL DEFAULT '',
    "notes" TEXT,
    "updated_at" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
CREATE INDEX IF NOT EXISTS idx_provision_stream_cluster_pkey ON provision_stream ("cluster", "pkey");

COMMIT;
