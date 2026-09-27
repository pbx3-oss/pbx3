-- CoS profiles Slice A: profile tables for existing DBs.
-- Applied idempotently by apply-sqlite-add-cos-profiles.sh (PRAGMA for ipphone.cos_profile).
-- Fresh installs: sqlite_create_tenant.sql already includes these definitions.

CREATE TABLE IF NOT EXISTS cos_profile (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "description" TEXT,
    "is_default" TEXT DEFAULT 'NO',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

CREATE TABLE IF NOT EXISTS cos_profile_open (
    "id" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "active" TEXT DEFAULT 'YES',
    "profile_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, profile_pkey, cos_pkey)
);

CREATE TABLE IF NOT EXISTS cos_profile_closed (
    "id" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "active" TEXT DEFAULT 'YES',
    "profile_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, profile_pkey, cos_pkey)
);
