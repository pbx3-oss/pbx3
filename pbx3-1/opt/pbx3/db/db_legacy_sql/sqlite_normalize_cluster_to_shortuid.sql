-- Normalize tenant-scoped `cluster` columns to cluster.shortuid.
--
-- Use when a restored/mixed DB has some rows on tenant pkey (or KSUID) and some on shortuid
-- (including fleets that previously had a partial SARK V6 import).
--
-- Safe to re-run (idempotent):
--   - Only updates rows whose cluster value matches a known cluster pkey, shortuid, or id.
--   - Rows already on shortuid are set to the same shortuid (no-op).
--   - Unknown / orphan cluster values are left unchanged.
--
-- One-shot SARK V6 import (fixRi / create_legacy / lineio / refactor*) lives in
-- aelintra/sark-to-pbx3 — not in this package. Prefer offline v2 there.
--
-- Apply:
--   sudo sqlite3 /opt/pbx3/db/sqlite.db < /opt/pbx3/db/db_legacy_sql/sqlite_normalize_cluster_to_shortuid.sql
--
-- Optional pre-check (expect pkey_form > 0 before, 0 after):
--   SELECT 'ipphone' AS tbl, cluster, COUNT(*) FROM ipphone GROUP BY cluster;
--
BEGIN TRANSACTION;

UPDATE agent
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = agent.cluster OR shortuid = agent.cluster OR id = agent.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = agent.cluster OR c.shortuid = agent.cluster OR c.id = agent.cluster
);

UPDATE appl
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = appl.cluster OR shortuid = appl.cluster OR id = appl.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = appl.cluster OR c.shortuid = appl.cluster OR c.id = appl.cluster
);

UPDATE cos
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = cos.cluster OR shortuid = cos.cluster OR id = cos.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = cos.cluster OR c.shortuid = cos.cluster OR c.id = cos.cluster
);

UPDATE dateseg
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = dateseg.cluster OR shortuid = dateseg.cluster OR id = dateseg.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = dateseg.cluster OR c.shortuid = dateseg.cluster OR c.id = dateseg.cluster
);

UPDATE greeting
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = greeting.cluster OR shortuid = greeting.cluster OR id = greeting.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = greeting.cluster OR c.shortuid = greeting.cluster OR c.id = greeting.cluster
);

UPDATE holiday
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = holiday.cluster OR shortuid = holiday.cluster OR id = holiday.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = holiday.cluster OR c.shortuid = holiday.cluster OR c.id = holiday.cluster
);

UPDATE inroutes
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = inroutes.cluster OR shortuid = inroutes.cluster OR id = inroutes.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = inroutes.cluster OR c.shortuid = inroutes.cluster OR c.id = inroutes.cluster
);

UPDATE ipphone
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = ipphone.cluster OR shortuid = ipphone.cluster OR id = ipphone.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = ipphone.cluster OR c.shortuid = ipphone.cluster OR c.id = ipphone.cluster
);

UPDATE ipphonecosclosed
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = ipphonecosclosed.cluster
       OR shortuid = ipphonecosclosed.cluster
       OR id = ipphonecosclosed.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = ipphonecosclosed.cluster
       OR c.shortuid = ipphonecosclosed.cluster
       OR c.id = ipphonecosclosed.cluster
);

UPDATE ipphonecosopen
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = ipphonecosopen.cluster
       OR shortuid = ipphonecosopen.cluster
       OR id = ipphonecosopen.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = ipphonecosopen.cluster
       OR c.shortuid = ipphonecosopen.cluster
       OR c.id = ipphonecosopen.cluster
);

UPDATE ivrmenu
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = ivrmenu.cluster OR shortuid = ivrmenu.cluster OR id = ivrmenu.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = ivrmenu.cluster OR c.shortuid = ivrmenu.cluster OR c.id = ivrmenu.cluster
);

UPDATE meetme
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = meetme.cluster OR shortuid = meetme.cluster OR id = meetme.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = meetme.cluster OR c.shortuid = meetme.cluster OR c.id = meetme.cluster
);

UPDATE page
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = page.cluster OR shortuid = page.cluster OR id = page.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = page.cluster OR c.shortuid = page.cluster OR c.id = page.cluster
);

UPDATE queue
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = queue.cluster OR shortuid = queue.cluster OR id = queue.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = queue.cluster OR c.shortuid = queue.cluster OR c.id = queue.cluster
);

UPDATE route
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = route.cluster OR shortuid = route.cluster OR id = route.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = route.cluster OR c.shortuid = route.cluster OR c.id = route.cluster
);

UPDATE trunks
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = trunks.cluster OR shortuid = trunks.cluster OR id = trunks.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = trunks.cluster OR c.shortuid = trunks.cluster OR c.id = trunks.cluster
);

UPDATE users
SET cluster = (
    SELECT shortuid FROM cluster
    WHERE pkey = users.cluster OR shortuid = users.cluster OR id = users.cluster
)
WHERE EXISTS (
    SELECT 1 FROM cluster c
    WHERE c.pkey = users.cluster OR c.shortuid = users.cluster OR c.id = users.cluster
);

COMMIT;

-- Post-check: any remaining pkey-form cluster values (should be empty):
-- SELECT 'ipphone' AS tbl, cluster, COUNT(*) AS n FROM ipphone
--   WHERE cluster IN (SELECT pkey FROM cluster) GROUP BY cluster
-- UNION ALL
-- SELECT 'queue', cluster, COUNT(*) FROM queue
--   WHERE cluster IN (SELECT pkey FROM cluster) GROUP BY cluster;
--
-- Rows still on pkey after this script mean cluster.pkey did not match (orphan tenant label).
