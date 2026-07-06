#!/bin/bash
# Set system hostname and 127.0.1.1 in /etc/hosts from globals.shortuid.
#
# After backup restore on a fresh EC2, installer.sh may have set a throwaway hostname
# (e.g. mgp30c) before restore-backup-zip.sh replaced sqlite.db with the fleet identity.
# Safe to re-run when hostname already matches.

set -eu

. /opt/pbx3/scripts/bashconfig

_lc_label() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

if [ ! -e "$SYSDB" ]; then
    echo "ERROR: database not found: $SYSDB" >&2
    exit 1
fi

_g_short=$(sqlite3 "$SYSDB" "SELECT COALESCE(shortuid,'') FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null || true)
if [ -z "$_g_short" ]; then
    _g_fqdn=$(sqlite3 "$SYSDB" "SELECT COALESCE(fqdn,'') FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null || true)
    if [ -n "$_g_fqdn" ] && echo "$_g_fqdn" | grep -q '\.'; then
        _g_short=$(_lc_label "$(echo "$_g_fqdn" | cut -d. -f1)")
    fi
fi

if [ -z "$_g_short" ]; then
    echo "sync-hostname-from-globals: no shortuid in globals" >&2
    exit 1
fi

_current=$(hostname 2>/dev/null || true)
if [ "$_current" = "$_g_short" ]; then
    echo "sync-hostname-from-globals: hostname already $_g_short"
    exit 0
fi

if /usr/bin/hostnamectl set-hostname "$_g_short" 2>/dev/null; then
    :
else
    echo "$_g_short" > /etc/hostname
    hostname "$_g_short" 2>/dev/null || true
fi

if [ -f /etc/hosts ]; then
    sed -i 's/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t'"$_g_short"'/' /etc/hosts
    grep -q '^127\.0\.1\.1[[:space:]]' /etc/hosts || sed -i '2i 127.0.1.1\t'"$_g_short" /etc/hosts
fi

echo "sync-hostname-from-globals: set hostname to $_g_short (was ${_current:-unknown})"
