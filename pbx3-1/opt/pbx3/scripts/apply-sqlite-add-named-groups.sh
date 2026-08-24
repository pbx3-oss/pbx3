#!/bin/sh
# Apply named_call_group + named_pickup_group idempotently.
# Migrates legacy named_groups (single field) into both columns when present.
# Usage: apply-sqlite-add-named-groups.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
HELP_SQL="$SQL_DIR/sqlite_update_named_pickup_groups_help.sql"

if [ ! -f "$DB" ]; then
	echo "skip named groups: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip named groups: sqlite3 not found" >&2
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
if ! has_col ipphone named_call_group; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN named_call_group TEXT DEFAULT 'ALL';"
	added=1
fi
if ! has_col ipphone named_pickup_group; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN named_pickup_group TEXT DEFAULT 'ALL';"
	added=1
fi

# Legacy single field → both sides (only when still present).
if has_col ipphone named_groups; then
	sqlite3 "$DB" "
UPDATE ipphone
SET named_call_group = CASE
	WHEN named_groups IS NOT NULL AND trim(named_groups) != '' THEN named_groups
	ELSE COALESCE(NULLIF(trim(named_call_group), ''), 'ALL')
END,
named_pickup_group = CASE
	WHEN named_groups IS NOT NULL AND trim(named_groups) != '' THEN named_groups
	ELSE COALESCE(NULLIF(trim(named_pickup_group), ''), 'ALL')
END
WHERE named_groups IS NOT NULL AND trim(named_groups) != '';
"
fi

# Normalize NULLs / blanks on new columns.
sqlite3 "$DB" "
UPDATE ipphone SET named_call_group='ALL' WHERE named_call_group IS NULL OR trim(named_call_group)='';
UPDATE ipphone SET named_pickup_group='ALL' WHERE named_pickup_group IS NULL OR trim(named_pickup_group)='';
"

if [ "$added" -eq 1 ]; then
	echo "added/ensured ipphone.named_call_group + named_pickup_group"
fi

if [ -f "$HELP_SQL" ] && has_table tt_help_core; then
	sqlite3 "$DB" < "$HELP_SQL" || true
	echo "named pickup groups help updated on $DB"
fi

exit 0
