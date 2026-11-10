#!/bin/sh
# Apply trunks.inbound_transform idempotently (solo inbound DID normalize).
# Usage: apply-sqlite-add-inbound-transform.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "skip inbound_transform: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip inbound_transform: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if has_col trunks inbound_transform; then
	echo "inbound_transform already present on trunks"
	exit 0
fi

sqlite3 "$DB" "ALTER TABLE trunks ADD COLUMN inbound_transform TEXT;"
echo "added trunks.inbound_transform"
