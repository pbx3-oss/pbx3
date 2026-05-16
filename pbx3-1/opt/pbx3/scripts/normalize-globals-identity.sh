#!/bin/bash
# Normalize globals.id (KSUID), pkey ('global'), and shortuid (subdomain from fqdn).
# Safe to re-run. Does not rebuild the database.
#
# Operators: you usually do NOT run this by hand.
#   - First server setup: use installer.sh (calls this at the end).
#   - pbx3 .deb upgrade: postinst runs this when sqlite.db exists.
#   - Manual run only after git pull of scripts without reinstalling the .deb.

set -eu

. /opt/pbx3/scripts/bashconfig

_sql_escape() { echo "$1" | sed "s/'/''/g"; }

if [ ! -e "$SYSDB" ]; then
    echo "ERROR: database not found: $SYSDB" >&2
    exit 1
fi

GCOUNT=$(sqlite3 "$SYSDB" "SELECT COUNT(*) FROM globals;" 2>/dev/null || echo "0")
if [ "$GCOUNT" -lt 1 ]; then
    echo "ERROR: globals table has no rows" >&2
    exit 1
fi

_g_id=$(sqlite3 "$SYSDB" "SELECT COALESCE(id,'') FROM globals LIMIT 1;" 2>/dev/null)
_g_pkey=$(sqlite3 "$SYSDB" "SELECT COALESCE(pkey,'') FROM globals LIMIT 1;" 2>/dev/null)
_g_fqdn=$(sqlite3 "$SYSDB" "SELECT COALESCE(fqdn,'') FROM globals LIMIT 1;" 2>/dev/null)
_g_short=$(sqlite3 "$SYSDB" "SELECT COALESCE(shortuid,'') FROM globals LIMIT 1;" 2>/dev/null)

_lc_label() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

changed=0

if [ -z "$_g_id" ] && [ "${#_g_pkey}" -eq 27 ]; then
    _e_pkey=$(_sql_escape "$_g_pkey")
    sqlite3 "$SYSDB" "UPDATE globals SET id='$_e_pkey', pkey='global' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
    echo "Set globals.id to KSUID (from legacy pkey), pkey=global"
    _g_id="$_g_pkey"
    changed=1
fi

if [ -z "$_g_short" ] && [ -n "$_g_fqdn" ] && echo "$_g_fqdn" | grep -q '\.'; then
    _g_short=$(_lc_label "$(echo "$_g_fqdn" | cut -d. -f1)")
    _e_short=$(_sql_escape "$_g_short")
    sqlite3 "$SYSDB" "UPDATE globals SET shortuid='$_e_short' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
    echo "Set globals.shortuid to $_g_short (from fqdn)"
    changed=1
fi

# Canonical lowercase shortuid (DNS / URL consistency).
if [ -n "$_g_short" ]; then
    _sl=$(_lc_label "$_g_short")
    if [ "$_g_short" != "$_sl" ]; then
        sqlite3 "$SYSDB" "UPDATE globals SET shortuid='$(_sql_escape "$_sl")' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
        echo "Lowercased globals.shortuid to $_sl"
        _g_short="$_sl"
        changed=1
    fi
fi

# Lowercase first label of globals.fqdn if needed (matches shortuid / DNS behaviour).
if [ -n "$_g_fqdn" ] && echo "$_g_fqdn" | grep -q '\.'; then
    _first=$(_lc_label "$(echo "$_g_fqdn" | cut -d. -f1)")
    _rest=$(echo "$_g_fqdn" | cut -d. -f2-)
    _fq_new="${_first}.${_rest}"
    if [ "$_fq_new" != "$_g_fqdn" ]; then
        sqlite3 "$SYSDB" "UPDATE globals SET fqdn='$(_sql_escape "$_fq_new")' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
        echo "Lowercased globals.fqdn first label -> $_fq_new"
        _g_fqdn="$_fq_new"
        changed=1
    fi
fi

if [ -n "$_g_id" ]; then
    mkdir -p "$(dirname "$INSTANCEID")"
    echo "$_g_id" > "$INSTANCEID"
fi

if [ "$changed" -eq 0 ]; then
    echo "globals identity already normalized (id, pkey, shortuid)"
fi

echo "Current globals identity:"
sqlite3 -header -column "$SYSDB" "SELECT id, shortuid, pkey, domain, fqdn FROM globals LIMIT 1;"
