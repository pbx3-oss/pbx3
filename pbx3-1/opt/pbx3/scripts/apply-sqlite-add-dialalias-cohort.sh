#!/bin/sh
# Add dialalias.source + dialalias.cohort_id for Site Group projections (C2).
# Idempotent. Usage: apply-sqlite-add-dialalias-cohort.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "skip dialalias cohort cols: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip dialalias cohort cols: sqlite3 not found" >&2
	exit 0
}

has_table() {
	sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$1';" | grep -q 1
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if ! has_table dialalias; then
	echo "skip dialalias cohort cols: no dialalias table" >&2
	exit 0
fi

if ! has_col dialalias source; then
	sqlite3 "$DB" "ALTER TABLE dialalias ADD COLUMN source TEXT DEFAULT 'manual';"
	echo "added dialalias.source"
fi

if ! has_col dialalias cohort_id; then
	sqlite3 "$DB" "ALTER TABLE dialalias ADD COLUMN cohort_id TEXT;"
	echo "added dialalias.cohort_id"
fi

# Normalize NULLs from older rows
sqlite3 "$DB" "UPDATE dialalias SET source = 'manual' WHERE source IS NULL OR trim(source) = '';"

echo "dialalias cohort columns ok"
