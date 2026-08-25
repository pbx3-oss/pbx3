-- Tenant CLID block list (greenfield). Safe to re-run (IF NOT EXISTS).
BEGIN;

CREATE TABLE IF NOT EXISTS clid_block (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "action" TEXT DEFAULT 'hangup',
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
CREATE INDEX IF NOT EXISTS idx_clid_block_cluster_pkey ON clid_block ("cluster", "pkey");

COMMIT;
