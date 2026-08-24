#!/bin/sh
# Apply sqlite_add_overlay_columns.sql idempotently (SQLite has no ADD COLUMN IF NOT EXISTS).
# Usage: apply-sqlite-add-overlay-columns.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
SQL="$SQL_DIR/sqlite_add_overlay_columns.sql"

if [ ! -f "$DB" ]; then
	echo "skip overlay columns: no DB at $DB" >&2
	exit 0
fi
if [ ! -f "$SQL" ]; then
	echo "skip overlay columns: missing $SQL" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip overlay columns: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

apply_one() {
	table="$1"
	col="$2"
	decl="$3"
	if has_col "$table" "$col"; then
		return 0
	fi
	sqlite3 "$DB" "ALTER TABLE $table ADD COLUMN $decl;"
	echo "added $table.$col"
}

# Keep in sync with sqlite_add_overlay_columns.sql
apply_one ipphone pjsip_overlay "pjsip_overlay TEXT"
apply_one trunks pjsip_overlay "pjsip_overlay TEXT"
apply_one queue queue_overlay "queue_overlay TEXT"
apply_one cluster park_overlay "park_overlay TEXT"

HELP_SQL="$SQL_DIR/sqlite_update_pjsip_overlay_help.sql"
if [ -f "$HELP_SQL" ]; then
	has_table=$(sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='tt_help_core' LIMIT 1;" || true)
	if [ "$has_table" = "1" ]; then
		sqlite3 "$DB" < "$HELP_SQL" || true
		echo "pjsip_overlay help updated on $DB"
	fi
fi

exit 0
