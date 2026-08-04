-- Tenant short dial: dialalias with target_fqdn (A′ Q14).
-- Safe to run multiple times (IF NOT EXISTS) on greenfield DBs that never had the table.
BEGIN;

CREATE TABLE IF NOT EXISTS dialalias (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "target_cluster" TEXT,
    "target_fqdn" TEXT NOT NULL,
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

COMMIT;
