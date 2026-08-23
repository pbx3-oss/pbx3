#!/bin/sh
# Apply sqlite_add_named_groups.sql idempotently (SQLite has no ADD COLUMN IF NOT EXISTS).
# Usage: apply-sqlite-add-named-groups.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
SQL="$SQL_DIR/sqlite_add_named_groups.sql"

if [ ! -f "$DB" ]; then
	echo "skip named_groups: no DB at $DB" >&2
	exit 0
fi
if [ ! -f "$SQL" ]; then
	echo "skip named_groups: missing $SQL" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip named_groups: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if has_col ipphone named_groups; then
	exit 0
fi
sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN named_groups TEXT DEFAULT 'ALL';"
# Existing rows: SQLite may leave NULLs on ADD COLUMN depending on version — normalize.
sqlite3 "$DB" "UPDATE ipphone SET named_groups='ALL' WHERE named_groups IS NULL OR trim(named_groups)='';"
echo "added ipphone.named_groups"
exit 0
