-- Tenant short dial slice A: per-calling-tenant dial aliases.
-- Safe to run multiple times (IF NOT EXISTS).
BEGIN;

CREATE TABLE IF NOT EXISTS dialalias (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "target_cluster" TEXT NOT NULL,
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

COMMIT;
