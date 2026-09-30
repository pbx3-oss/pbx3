#!/bin/sh
# Ensure ipphone provision columns: sndcreds, last/first_provisioned_at,
# and provision / provisionwith if missing on older DBs.
# Usage: apply-sqlite-add-provision-columns.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"

if [ ! -f "$DB" ]; then
	echo "skip provision columns: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip provision columns: sqlite3 not found" >&2
	exit 0
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

added=0
if ! has_col ipphone provision; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN provision TEXT;"
	added=1
fi
if ! has_col ipphone provisionwith; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN provisionwith TEXT DEFAULT 'IP';"
	added=1
fi
if ! has_col ipphone sndcreds; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN sndcreds TEXT DEFAULT 'Once';"
	added=1
fi
if ! has_col ipphone last_provisioned_at; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN last_provisioned_at TEXT;"
	added=1
fi
if ! has_col ipphone first_provisioned_at; then
	sqlite3 "$DB" "ALTER TABLE ipphone ADD COLUMN first_provisioned_at TEXT;"
	added=1
fi

if [ "$added" -eq 1 ]; then
	echo "added/ensured ipphone provision columns on $DB"
else
	echo "ipphone provision columns already present on $DB"
fi
exit 0
