#!/bin/sh
# Apply time-based routing schema columns + profile tables (idempotent).
# Usage: apply-sqlite-add-time-based-routing.sh [/path/to/sqlite.db]
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
SQL_DIR="$(CDPATH= cd -- "$(dirname "$0")/../db/db_sql" && pwd)"
SQL="$SQL_DIR/sqlite_add_time_based_routing.sql"

if [ ! -f "$DB" ]; then
	echo "skip time-based routing schema: no DB at $DB" >&2
	exit 0
fi
if [ ! -f "$SQL" ]; then
	echo "skip time-based routing schema: missing $SQL" >&2
	exit 0
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "skip time-based routing schema: sqlite3 not found" >&2
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

has_table() {
	sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$1';" | grep -q 1
}

# --- columns ---
if has_table cluster; then
	apply_one cluster sched_mode "sched_mode TEXT"
	apply_one cluster holiday_force_mode "holiday_force_mode TEXT"
	apply_one cluster holiday_force_dest "holiday_force_dest TEXT"
fi
if has_table dateseg; then
	apply_one dateseg mode "mode TEXT DEFAULT 'closed'"
	apply_one dateseg priority "priority INTEGER DEFAULT 0"
fi
if has_table holiday; then
	apply_one holiday force_mode "force_mode TEXT"
	apply_one holiday force_dest "force_dest TEXT"
fi
if has_table inroutes; then
	apply_one inroutes route_profile "route_profile TEXT"
	apply_one inroutes entry_dest "entry_dest TEXT"
fi

# --- profile tables ---
sqlite3 "$DB" < "$SQL"
echo "time-based routing schema applied on $DB"

HELP_SQL="$SQL_DIR/sqlite_update_day_parts_help.sql"
if [ -f "$HELP_SQL" ] && has_table tt_help_core; then
	sqlite3 "$DB" < "$HELP_SQL" || true
	echo "day-parts help updated on $DB"
fi

exit 0
