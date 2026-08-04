#!/bin/sh
# Idempotent convert: open/close DID pairs → route_profile + dual-read columns.
# Requires schema from apply-sqlite-add-time-based-routing.sh first.
# Usage: convert-route-profiles.sh [/path/to/sqlite.db]
#
# Accept: open/close destinations for DIDs unchanged after convert (columns kept).
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "convert-route-profiles: no DB at $DB" >&2
	exit 1
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "convert-route-profiles: sqlite3 not found" >&2
	exit 1
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if ! has_col inroutes route_profile; then
	echo "convert-route-profiles: run apply-sqlite-add-time-based-routing.sh first" >&2
	exit 1
fi

# day timers: mode closed (match ⇒ closed historically)
if has_col dateseg mode; then
	sqlite3 "$DB" "UPDATE dateseg SET mode = 'closed' WHERE mode IS NULL OR TRIM(mode) = '';"
fi
if has_col dateseg priority; then
	sqlite3 "$DB" "UPDATE dateseg SET priority = 0 WHERE priority IS NULL;"
fi

# sched_mode from oclo
if has_col cluster sched_mode; then
	sqlite3 "$DB" <<'SQL'
UPDATE cluster SET sched_mode = lower(trim(oclo))
WHERE (sched_mode IS NULL OR trim(sched_mode) = '')
  AND oclo IS NOT NULL AND trim(oclo) != '';
UPDATE cluster SET sched_mode = 'open'
WHERE (sched_mode IS NULL OR trim(sched_mode) = '');
SQL
fi

# holiday force_dest from legacy route when empty
if has_col holiday force_dest; then
	sqlite3 "$DB" <<'SQL'
UPDATE holiday SET force_dest = route
WHERE (force_dest IS NULL OR trim(force_dest) = '')
  AND route IS NOT NULL AND trim(route) != '';
SQL
fi

# Build profiles per tenant for each distinct (openroute, closeroute) pair among DIDs that lack a profile.
# IDs: deterministic hex from pair so convert is idempotent.
# Also backfill route_profile_line for any profile missing open/closed lines.
sqlite3 "$DB" <<'SQL'
-- Distinct pairs that need a profile (DIDs with empty route_profile)
CREATE TEMP TABLE _rp_pairs AS
SELECT DISTINCT
  trim(coalesce(cluster, 'default')) AS cluster,
  coalesce(nullif(trim(openroute), ''), 'None') AS openroute,
  coalesce(nullif(trim(closeroute), ''), 'None') AS closeroute
FROM inroutes
WHERE (route_profile IS NULL OR trim(route_profile) = '');

-- Existing profile that already matches a pair (reuse shortuid)
CREATE TEMP TABLE _rp_existing AS
SELECT
  p.cluster AS cluster,
  max(CASE WHEN l.mode = 'open' THEN l.destination END) AS openroute,
  max(CASE WHEN l.mode = 'closed' THEN l.destination END) AS closeroute,
  p.shortuid AS shortuid
FROM route_profile p
LEFT JOIN route_profile_line l ON l.profile = p.shortuid
GROUP BY p.cluster, p.shortuid;

CREATE TEMP TABLE _rp_map (
  cluster TEXT,
  openroute TEXT,
  closeroute TEXT,
  shortuid TEXT,
  id TEXT
);

INSERT INTO _rp_map (cluster, openroute, closeroute, shortuid, id)
SELECT
  pr.cluster,
  pr.openroute,
  pr.closeroute,
  -- Full hex of open|closed|cluster so shared tenant prefix does not collide when truncated
  substr(lower(hex(printf('%s|%s|%s', pr.openroute, pr.closeroute, pr.cluster))), 1, 16),
  substr(lower(hex(printf('id|%s|%s|%s', pr.openroute, pr.closeroute, pr.cluster))), 1, 27)
FROM _rp_pairs pr;

-- Prefer reusing existing profile with same open/closed destinations
UPDATE _rp_map
SET shortuid = (
  SELECT e.shortuid FROM _rp_existing e
  WHERE e.cluster = _rp_map.cluster
    AND e.openroute = _rp_map.openroute
    AND e.closeroute = _rp_map.closeroute
  LIMIT 1
)
WHERE EXISTS (
  SELECT 1 FROM _rp_existing e
  WHERE e.cluster = _rp_map.cluster
    AND e.openroute = _rp_map.openroute
    AND e.closeroute = _rp_map.closeroute
);

INSERT OR IGNORE INTO route_profile (id, shortuid, pkey, cluster, name, default_mode, description, z_updater)
SELECT
  m.id,
  m.shortuid,
  m.shortuid,
  m.cluster,
  'Converted open/close',
  'open',
  printf('auto from %s / %s', m.openroute, m.closeroute),
  'convert-route-profiles'
FROM _rp_map m
WHERE NOT EXISTS (SELECT 1 FROM route_profile p WHERE p.shortuid = m.shortuid);

INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  substr(lower(hex(printf('id|o|%s|%s', m.shortuid, m.openroute))), 1, 27),
  substr(m.shortuid || '_open', 1, 24),
  m.shortuid,
  m.cluster,
  'open',
  m.openroute,
  'convert-route-profiles'
FROM _rp_map m
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = m.shortuid AND l.mode = 'open'
);

INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  substr(lower(hex(printf('id|c|%s|%s', m.shortuid, m.closeroute))), 1, 27),
  substr(m.shortuid || '_closed', 1, 24),
  m.shortuid,
  m.cluster,
  'closed',
  m.closeroute,
  'convert-route-profiles'
FROM _rp_map m
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = m.shortuid AND l.mode = 'closed'
);

UPDATE inroutes
SET route_profile = (
  SELECT m.shortuid FROM _rp_map m
  WHERE m.cluster = trim(coalesce(inroutes.cluster, 'default'))
    AND m.openroute = coalesce(nullif(trim(inroutes.openroute), ''), 'None')
    AND m.closeroute = coalesce(nullif(trim(inroutes.closeroute), ''), 'None')
  LIMIT 1
)
WHERE (route_profile IS NULL OR trim(route_profile) = '');

-- Backfill lines for profiles that already exist (headers without lines after shortuid collision bug)
INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  substr(lower(hex(printf('bf|o|%s|%s', i.route_profile, i.openroute))), 1, 27),
  substr(i.route_profile || '_open', 1, 24),
  i.route_profile,
  trim(coalesce(i.cluster, 'default')),
  'open',
  coalesce(nullif(trim(i.openroute), ''), 'None'),
  'convert-route-profiles'
FROM (
  SELECT route_profile, cluster,
         min(openroute) AS openroute,
         min(closeroute) AS closeroute
  FROM inroutes
  WHERE route_profile IS NOT NULL AND trim(route_profile) != ''
  GROUP BY route_profile, cluster
) i
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = i.route_profile AND l.mode = 'open'
);

INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  substr(lower(hex(printf('bf|c|%s|%s', i.route_profile, i.closeroute))), 1, 27),
  substr(i.route_profile || '_closed', 1, 24),
  i.route_profile,
  trim(coalesce(i.cluster, 'default')),
  'closed',
  coalesce(nullif(trim(i.closeroute), ''), 'None'),
  'convert-route-profiles'
FROM (
  SELECT route_profile, cluster,
         min(openroute) AS openroute,
         min(closeroute) AS closeroute
  FROM inroutes
  WHERE route_profile IS NOT NULL AND trim(route_profile) != ''
  GROUP BY route_profile, cluster
) i
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = i.route_profile AND l.mode = 'closed'
);

DROP TABLE _rp_pairs;
DROP TABLE _rp_existing;
DROP TABLE _rp_map;
SQL

profiles=$(sqlite3 "$DB" "SELECT count(*) FROM route_profile;")
linked=$(sqlite3 "$DB" "SELECT count(*) FROM inroutes WHERE route_profile IS NOT NULL AND trim(route_profile) != '';")
echo "convert-route-profiles: profiles=$profiles inroutes_with_profile=$linked on $DB"
exit 0
