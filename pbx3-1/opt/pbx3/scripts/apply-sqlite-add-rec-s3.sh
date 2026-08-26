#!/bin/sh
# Apply cluster.rec_s3 idempotently (S7 tenant S3 DR opt-in, default NO).
# Usage: apply-sqlite-add-rec-s3.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "skip rec_s3: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip rec_s3: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

if has_col cluster rec_s3; then
	echo "rec_s3 already present on cluster"
	exit 0
fi

sqlite3 "$DB" "ALTER TABLE cluster ADD COLUMN rec_s3 TEXT DEFAULT 'NO';"
sqlite3 "$DB" "UPDATE cluster SET rec_s3 = 'NO' WHERE rec_s3 IS NULL OR trim(rec_s3) = '';"
echo "added cluster.rec_s3 (default NO)"
