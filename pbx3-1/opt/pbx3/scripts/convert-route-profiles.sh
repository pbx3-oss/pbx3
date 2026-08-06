#!/bin/sh
# Idempotent convert: open/close DID pairs → route_profile + dual-read columns.
# Requires schema from apply-sqlite-add-time-based-routing.sh first.
# Usage: convert-route-profiles.sh [/path/to/sqlite.db]
#
# Accept: open/close destinations for DIDs unchanged after convert (columns kept).
# Profile shortuid = product 6-char idpwgen shortuid (not hex of open|close).
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
IDPWGEN="${IDPWGEN:-/opt/pbx3/golang/idpwgen}"
SHORTUID_CHARSET='0123456789bcdfghjkmnpqrstvwxyz'

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

# Product shortuid (6 chars, same charset as generate_shortuid / idpwgen).
# Reject all-digit (Slice D OpenSIPS gate needs a letter).
gen_shortuid() {
	tries=0
	while [ "$tries" -lt 64 ]; do
		if [ -x "$IDPWGEN" ]; then
			# Prefer flagged CLI; fall back to positional for older binaries
			suid=$("$IDPWGEN" -length 6 -charset "$SHORTUID_CHARSET" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d '[:space:]')
			if [ -z "$suid" ]; then
				suid=$("$IDPWGEN" 6 "$SHORTUID_CHARSET" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d '[:space:]')
			fi
		else
			# Test / offline fallback when idpwgen is absent
			suid=$(awk -v charset="$SHORTUID_CHARSET" 'BEGIN {
				srand();
				n = length(charset);
				out = "";
				for (i = 0; i < 6; i++) out = out substr(charset, int(rand() * n) + 1, 1);
				print out;
			}')
		fi
		tries=$((tries + 1))
		case "$suid" in
			*[!0-9]*) printf '%s\n' "$suid"; return 0 ;;
		esac
	done
	echo "convert-route-profiles: could not allocate shortuid with a letter" >&2
	exit 1
}

unique_shortuid() {
	tries=0
	while [ "$tries" -lt 32 ]; do
		suid=$(gen_shortuid)
		exists=$(sqlite3 "$DB" "SELECT 1 FROM route_profile WHERE shortuid = '$suid' LIMIT 1;")
		if [ -z "$exists" ]; then
			printf '%s\n' "$suid"
			return 0
		fi
		tries=$((tries + 1))
	done
	echo "convert-route-profiles: could not allocate unique shortuid" >&2
	exit 1
}

sql_escape() {
	printf "%s" "$1" | sed "s/'/''/g"
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

# Remap legacy convert hex / non-product shortuids → real 6-char shortuids.
# Safe to re-run: only touches length(shortuid) != 6.
sqlite3 "$DB" "SELECT shortuid FROM route_profile WHERE length(shortuid) != 6;" | while IFS= read -r old || [ -n "$old" ]; do
	[ -z "$old" ] && continue
	new=$(unique_shortuid)
	old_esc=$(sql_escape "$old")
	new_esc=$(sql_escape "$new")
	sqlite3 "$DB" <<SQL
BEGIN;
UPDATE route_profile SET shortuid = '$new_esc', pkey = '$new_esc' WHERE shortuid = '$old_esc';
UPDATE route_profile_line SET profile = '$new_esc' WHERE profile = '$old_esc';
UPDATE route_profile_line SET shortuid = substr('$new_esc' || '_open', 1, 24)
  WHERE profile = '$new_esc' AND mode = 'open' AND shortuid LIKE '%_open';
UPDATE route_profile_line SET shortuid = substr('$new_esc' || '_closed', 1, 24)
  WHERE profile = '$new_esc' AND mode = 'closed' AND shortuid LIKE '%_closed';
UPDATE inroutes SET route_profile = '$new_esc' WHERE route_profile = '$old_esc';
COMMIT;
SQL
	echo "convert-route-profiles: remapped profile $old → $new"
done

# Build profiles per tenant for each distinct (openroute, closeroute) pair among DIDs that lack a profile.
# Reuse existing profile with same open/closed lines when present; else allocate a 6-char shortuid.
sqlite3 -separator '	' "$DB" <<'SQL' | while IFS='	' read -r cluster openroute closeroute || [ -n "$cluster" ]; do
SELECT DISTINCT
  trim(coalesce(cluster, 'default')),
  coalesce(nullif(trim(openroute), ''), 'None'),
  coalesce(nullif(trim(closeroute), ''), 'None')
FROM inroutes
WHERE (route_profile IS NULL OR trim(route_profile) = '');
SQL
	[ -z "${cluster:-}" ] && continue
	cluster_esc=$(sql_escape "$cluster")
	open_esc=$(sql_escape "$openroute")
	close_esc=$(sql_escape "$closeroute")

	existing=$(sqlite3 "$DB" <<SQL
SELECT p.shortuid
FROM route_profile p
LEFT JOIN route_profile_line lo ON lo.profile = p.shortuid AND lo.mode = 'open'
LEFT JOIN route_profile_line lc ON lc.profile = p.shortuid AND lc.mode = 'closed'
WHERE p.cluster = '$cluster_esc'
  AND coalesce(lo.destination, '') = '$open_esc'
  AND coalesce(lc.destination, '') = '$close_esc'
LIMIT 1;
SQL
)

	if [ -n "$existing" ]; then
		suid=$existing
	else
		suid=$(unique_shortuid)
		suid_esc=$(sql_escape "$suid")
		id_esc=$(sql_escape "rp$(printf '%s' "$suid" | sed 's/[^0-9a-z]//g')$(awk 'BEGIN{srand(); printf "%08d", int(rand()*1e8)}')")
		sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO route_profile (id, shortuid, pkey, cluster, name, default_mode, description, z_updater)
VALUES (
  '$id_esc',
  '$suid_esc',
  '$suid_esc',
  '$cluster_esc',
  'Converted open/close',
  'open',
  'auto from $open_esc / $close_esc',
  'convert-route-profiles'
);
INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
VALUES (
  '${id_esc}_o',
  substr('$suid_esc' || '_open', 1, 24),
  '$suid_esc',
  '$cluster_esc',
  'open',
  '$open_esc',
  'convert-route-profiles'
);
INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
VALUES (
  '${id_esc}_c',
  substr('$suid_esc' || '_closed', 1, 24),
  '$suid_esc',
  '$cluster_esc',
  'closed',
  '$close_esc',
  'convert-route-profiles'
);
SQL
	fi

	suid_esc=$(sql_escape "$suid")
	sqlite3 "$DB" <<SQL
UPDATE inroutes
SET route_profile = '$suid_esc'
WHERE (route_profile IS NULL OR trim(route_profile) = '')
  AND trim(coalesce(cluster, 'default')) = '$cluster_esc'
  AND coalesce(nullif(trim(openroute), ''), 'None') = '$open_esc'
  AND coalesce(nullif(trim(closeroute), ''), 'None') = '$close_esc';
SQL
done

# Backfill open/closed lines for profiles that already exist but lack lines
sqlite3 -separator '	' "$DB" <<'SQL' | while IFS='	' read -r profile cluster openroute closeroute || [ -n "$profile" ]; do
SELECT i.route_profile, trim(coalesce(i.cluster, 'default')),
       coalesce(nullif(trim(min(i.openroute)), ''), 'None'),
       coalesce(nullif(trim(min(i.closeroute)), ''), 'None')
FROM inroutes i
WHERE i.route_profile IS NOT NULL AND trim(i.route_profile) != ''
GROUP BY i.route_profile, trim(coalesce(i.cluster, 'default'));
SQL
	[ -z "${profile:-}" ] && continue
	profile_esc=$(sql_escape "$profile")
	cluster_esc=$(sql_escape "$cluster")
	open_esc=$(sql_escape "$openroute")
	close_esc=$(sql_escape "$closeroute")
	sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  'bf_o_' || '$profile_esc',
  substr('$profile_esc' || '_open', 1, 24),
  '$profile_esc',
  '$cluster_esc',
  'open',
  '$open_esc',
  'convert-route-profiles'
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = '$profile_esc' AND l.mode = 'open'
);
INSERT OR IGNORE INTO route_profile_line (id, shortuid, profile, cluster, mode, destination, z_updater)
SELECT
  'bf_c_' || '$profile_esc',
  substr('$profile_esc' || '_closed', 1, 24),
  '$profile_esc',
  '$cluster_esc',
  'closed',
  '$close_esc',
  'convert-route-profiles'
WHERE NOT EXISTS (
  SELECT 1 FROM route_profile_line l WHERE l.profile = '$profile_esc' AND l.mode = 'closed'
);
SQL
done

profiles=$(sqlite3 "$DB" "SELECT count(*) FROM route_profile;")
linked=$(sqlite3 "$DB" "SELECT count(*) FROM inroutes WHERE route_profile IS NOT NULL AND trim(route_profile) != '';")
bad=$(sqlite3 "$DB" "SELECT count(*) FROM route_profile WHERE length(shortuid) != 6;")
echo "convert-route-profiles: profiles=$profiles inroutes_with_profile=$linked non6_shortuid=$bad on $DB"
if [ "$bad" -ne 0 ]; then
	echo "convert-route-profiles: warning: $bad profile(s) still have non-6-char shortuid" >&2
	exit 1
fi
exit 0
