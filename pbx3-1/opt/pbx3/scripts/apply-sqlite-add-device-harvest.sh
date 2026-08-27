#!/bin/sh
# Apply devicevendor + firstseen/lastseen; normalize ipphone.device to type enum.
# Usage: apply-sqlite-add-device-harvest.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
HELP_SQL="$SQL_DIR/sqlite_update_device_harvest_help.sql"

if [ ! -f "$DB" ]; then
	echo "skip device harvest: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip device harvest: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

has_table() {
	table="$1"
	sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$table' LIMIT 1;" | grep -q 1
}

added=0
if ! has_col ipphone devicevendor; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN devicevendor TEXT;"
	added=1
fi
if ! has_col ipphone firstseen; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN firstseen TEXT;"
	added=1
fi
if ! has_col ipphone lastseen; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN lastseen TEXT;"
	added=1
fi
# devicemodel already on most fleets from create SQL; ensure for old DBs
if ! has_col ipphone devicemodel; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN devicemodel TEXT;"
	added=1
fi

# Type enum only: WebRTC | MAILBOX | General SIP (canonicalize case).
sqlite3 "$DB" "
UPDATE ipphone SET device = CASE
	WHEN lower(trim(COALESCE(device,''))) = 'webrtc' THEN 'WebRTC'
	WHEN lower(trim(COALESCE(device,''))) = 'mailbox' THEN 'MAILBOX'
	WHEN lower(trim(COALESCE(device,''))) = 'general sip' THEN 'General SIP'
	ELSE 'General SIP'
END;
"

if [ "$added" -eq 1 ]; then
	echo "added/ensured ipphone devicevendor/firstseen/lastseen/devicemodel"
fi
echo "normalized ipphone.device to type enum on $DB"

if [ -f "$HELP_SQL" ] && has_table tt_help_core; then
	sqlite3 "$DB" < "$HELP_SQL" || true
	echo "device harvest help updated on $DB"
fi

exit 0
