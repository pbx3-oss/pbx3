#!/bin/sh
# Ensure tenant table provision_stream (B4 customer site fragments).
# Usage: apply-sqlite-add-provision-stream.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
SQL="$SQL_DIR/sqlite_add_provision_stream.sql"

if [ ! -f "$DB" ]; then
	echo "skip provision_stream: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip provision_stream: sqlite3 not found" >&2
	exit 0
}
if [ ! -f "$SQL" ]; then
	echo "skip provision_stream: missing $SQL" >&2
	exit 0
fi

exists=$(sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='provision_stream' LIMIT 1;")
if [ "$exists" = "1" ]; then
	echo "provision_stream already present on $DB"
	exit 0
fi

sqlite3 "$DB" < "$SQL"
echo "created provision_stream on $DB"
exit 0
