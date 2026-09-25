#!/bin/sh
# Apply queue.caller_timeout idempotently (Caller Max Wait / Queue() 5th arg).
# Usage: apply-sqlite-add-queue-caller-timeout.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "skip queue.caller_timeout: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip queue.caller_timeout: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if has_col queue caller_timeout; then
	echo "caller_timeout already present on queue"
	exit 0
fi

sqlite3 "$DB" "ALTER TABLE queue ADD COLUMN caller_timeout INTEGER;"
echo "added queue.caller_timeout (NULL = unlimited Caller Max Wait)"
