#!/bin/sh
# Apply CoS profile schema (tables + ipphone.cos_profile). Idempotent.
# Usage: apply-sqlite-add-cos-profiles.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
SQL="$SQL_DIR/sqlite_add_cos_profiles.sql"

if [ ! -f "$DB" ]; then
	echo "skip cos profiles schema: no DB at $DB" >&2
	exit 0
fi
if [ ! -f "$SQL" ]; then
	echo "skip cos profiles schema: missing $SQL" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip cos profiles schema: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

has_table() {
	sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$1';" | grep -q 1
}

if has_table ipphone && ! has_col ipphone cos_profile; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN cos_profile TEXT;"
	echo "added ipphone.cos_profile"
fi

sqlite3 "$DB" < "$SQL"
echo "cos profiles schema applied on $DB"
exit 0
