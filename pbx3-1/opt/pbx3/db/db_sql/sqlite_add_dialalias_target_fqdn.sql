-- Tenant short dial A′ (Q14): required target_fqdn; target_cluster optional (label pin).
-- Run once on DBs that already have dialalias without target_fqdn.
-- Re-running on a table that already has target_fqdn will fail (rebuild assumes prior layout).

BEGIN;

CREATE TABLE dialalias__afqdn (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',       -- calling tenant shortuid
    "target_cluster" TEXT,                  -- optional shortuid pin
    "target_fqdn" TEXT NOT NULL,            -- dial target: full tenant FQDN
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

INSERT INTO dialalias__afqdn (
    id, shortuid, pkey, active, cluster, target_cluster, target_fqdn,
    cname, description, z_created, z_updated, z_updater
)
SELECT
    d.id,
    d.shortuid,
    d.pkey,
    d.active,
    d.cluster,
    NULLIF(TRIM(COALESCE(d.target_cluster, '')), ''),
    COALESCE(
        (
            SELECT LOWER(TRIM(c.fqdn))
            FROM cluster c
            WHERE c.shortuid = d.target_cluster
               OR c.pkey = d.target_cluster
               OR c.id = d.target_cluster
            LIMIT 1
        ),
        -- Last resort if target shortuid not in local cluster (should not happen pre-A′)
        LOWER(TRIM(COALESCE(d.target_cluster, 'unknown'))) || '.invalid'
    ),
    d.cname,
    d.description,
    d.z_created,
    d.z_updated,
    d.z_updater
FROM dialalias d;

DROP TABLE dialalias;
ALTER TABLE dialalias__afqdn RENAME TO dialalias;

COMMIT;
