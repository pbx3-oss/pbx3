#!/bin/sh
# Apply globals.default_outbound_dialplan (idempotent).
# Usage: apply-sqlite-add-default-outbound-dialplan.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"

if [ ! -f "$DB" ]; then
	echo "skip default_outbound_dialplan: no DB at $DB" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip default_outbound_dialplan: sqlite3 not found" >&2
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

if ! has_table globals; then
	echo "skip default_outbound_dialplan: no globals table" >&2
	exit 0
fi

if ! has_col globals default_outbound_dialplan; then
	sqlite3 "$DB" "ALTER TABLE globals ADD COLUMN default_outbound_dialplan TEXT DEFAULT '_0XXX. _00XX.';"
	echo "added globals.default_outbound_dialplan"
fi

# Seed empty/NULL; migrate pre-#4c UK seed to L7a-safe patterns (do not rewrite custom strings).
sqlite3 "$DB" "UPDATE globals SET default_outbound_dialplan = '_0XXX. _00XX.' WHERE default_outbound_dialplan IS NULL OR trim(default_outbound_dialplan) = '' OR trim(default_outbound_dialplan) = '_0. _00.';"

HELP_SQL="$SQL_DIR/sqlite_update_default_outbound_dialplan_help.sql"
if [ -f "$HELP_SQL" ] && has_table tt_help_core; then
	sqlite3 "$DB" < "$HELP_SQL" || true
fi

echo "default_outbound_dialplan applied on $DB"
exit 0
