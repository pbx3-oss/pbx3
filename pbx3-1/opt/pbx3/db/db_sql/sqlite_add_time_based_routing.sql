-- Time-based routing slice A: columns + profile tables for existing DBs.
-- Applied idempotently by apply-sqlite-add-time-based-routing.sh (PRAGMA per column).
-- Fresh installs: sqlite_create_tenant.sql already includes these definitions.

-- cluster
-- ALTER TABLE cluster ADD COLUMN sched_mode TEXT;
-- ALTER TABLE cluster ADD COLUMN holiday_force_mode TEXT;
-- ALTER TABLE cluster ADD COLUMN holiday_force_dest TEXT;

-- dateseg
-- ALTER TABLE dateseg ADD COLUMN mode TEXT DEFAULT 'closed';
-- ALTER TABLE dateseg ADD COLUMN priority INTEGER DEFAULT 0;

-- holiday
-- ALTER TABLE holiday ADD COLUMN force_mode TEXT;
-- ALTER TABLE holiday ADD COLUMN force_dest TEXT;

-- inroutes
-- ALTER TABLE inroutes ADD COLUMN route_profile TEXT;
-- ALTER TABLE inroutes ADD COLUMN entry_dest TEXT;

CREATE TABLE IF NOT EXISTS route_profile (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "name" TEXT,
    "default_mode" TEXT DEFAULT 'open',
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);

CREATE TABLE IF NOT EXISTS route_profile_line (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "profile" TEXT NOT NULL,
    "cluster" TEXT DEFAULT 'default',
    "mode" TEXT NOT NULL,
    "destination" TEXT NOT NULL,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("profile", "mode")
);
