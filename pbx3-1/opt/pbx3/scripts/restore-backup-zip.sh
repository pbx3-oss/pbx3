#!/bin/bash
# Restore a local pbx3bak.*.zip onto this node (S8 rebuild runbook).
#
# Same payload as SPA/API restore with restoredb + restoreasterisk + greetings + voicemail.
# Does NOT run reloader.sh — restored sqlite.db is the source of truth.
#
# Usage:
#   sudo /opt/pbx3/scripts/restore-backup-zip.sh /opt/pbx3/bkup/pbx3bak.1716123456.zip
#   sudo /opt/pbx3/scripts/restore-backup-zip.sh --full pbx3bak.1716123456.zip
#
# Default (--full implied): DB + Asterisk + greetings + voicemail.

set -eu

. /opt/pbx3/scripts/bashconfig

FULL=1
ZIP_ARG=""

usage() {
  cat <<'EOF'
Usage: restore-backup-zip.sh [--full|--db-only] PATH|basename

  --full     restore DB, /etc/asterisk, greetings, voicemail (default)
  --db-only  restore sqlite.db only
  PATH       absolute path or basename under /opt/pbx3/bkup/

Run as root. Do not run reloader.sh after this script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FULL=1; shift ;;
    --db-only) FULL=0; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "restore-backup-zip: unknown option: $1" >&2; usage; exit 1 ;;
    *) ZIP_ARG=$1; shift ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || { echo "restore-backup-zip: run as root (sudo)" >&2; exit 1; }
[[ -n "$ZIP_ARG" ]] || { echo "restore-backup-zip: missing backup zip argument" >&2; usage; exit 1; }

BASENAME="$(basename "$ZIP_ARG")"
if [[ "$ZIP_ARG" = "$BASENAME" ]]; then
  ZIP_PATH="${BKUPPATH}/${BASENAME}"
else
  ZIP_PATH="$ZIP_ARG"
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "restore-backup-zip: file not found: $ZIP_PATH" >&2
  exit 1
fi

if [[ ! "$BASENAME" =~ ^pbx3bak\.[0-9]+\.zip$ ]]; then
  echo "restore-backup-zip: expected pbx3bak.{epoch}.zip, got: $BASENAME" >&2
  exit 1
fi

TEMP_D="/tmp/pbx3-restore-$$"
mkdir -p "$TEMP_D"
trap 'rm -rf "$TEMP_D"' EXIT

echo "restore-backup-zip: extracting $ZIP_PATH ..."
/usr/bin/unzip -q "$ZIP_PATH" -d "$TEMP_D"

restore_db() {
  local db_source=""
  if [[ -f "$TEMP_D/opt/pbx3/db/sqlite.db" ]]; then
    db_source="$TEMP_D/opt/pbx3/db/sqlite.db"
  elif [[ -f "$TEMP_D/opt/pbx3/db/pbx3.db" ]]; then
    db_source="$TEMP_D/opt/pbx3/db/pbx3.db"
  fi
  if [[ -z "$db_source" ]]; then
    echo "restore-backup-zip: no database in backup — skipped" >&2
    return 0
  fi
  echo "restore-backup-zip: restoring database from backup"
  /bin/cp -f "$db_source" "$SYSDB"
  /bin/chown www-data:www-data "$SYSDB"
  /bin/chmod 664 "$SYSDB"
}

restore_asterisk() {
  if [[ ! -d "$TEMP_D/etc/asterisk" ]]; then
    echo "restore-backup-zip: no Asterisk tree in backup — skipped" >&2
    return 0
  fi
  echo "restore-backup-zip: restoring /etc/asterisk"
  /bin/rm -rf /etc/asterisk/*
  /bin/cp -a "$TEMP_D/etc/asterisk/"* /etc/asterisk/
  /bin/chown asterisk:asterisk /etc/asterisk/* 2>/dev/null || true
  /bin/chmod 664 /etc/asterisk/* 2>/dev/null || true
}

restore_greetings() {
  local g
  g=$(compgen -G "$TEMP_D/usr/share/asterisk/sounds/usergreeting*" || true)
  if [[ -z "$g" ]]; then
    echo "restore-backup-zip: no user greetings in backup — skipped" >&2
    return 0
  fi
  echo "restore-backup-zip: restoring user greetings"
  /bin/rm -rf /usr/share/asterisk/sounds/usergreeting*
  /bin/cp -a "$TEMP_D/usr/share/asterisk/sounds/usergreeting"* /usr/share/asterisk/sounds/
  /bin/chown asterisk:asterisk /usr/share/asterisk/sounds/usergreeting* 2>/dev/null || true
}

restore_voicemail() {
  if [[ ! -d "$TEMP_D/var/spool/asterisk/voicemail/default" ]]; then
    echo "restore-backup-zip: no voicemail in backup — skipped" >&2
    return 0
  fi
  echo "restore-backup-zip: restoring voicemail"
  /bin/rm -rf /var/spool/asterisk/voicemail/default
  /bin/cp -a "$TEMP_D/var/spool/asterisk/voicemail/default" /var/spool/asterisk/voicemail/
  /bin/chown -R asterisk:asterisk /var/spool/asterisk/voicemail/default
}

restore_db
if [[ "$FULL" -eq 1 ]]; then
  restore_asterisk
  restore_greetings
  restore_voicemail
fi

if [[ -x /opt/pbx3/scripts/normalize-globals-identity.sh ]]; then
  /bin/sh /opt/pbx3/scripts/normalize-globals-identity.sh || true
fi

if [[ -x /opt/pbx3/scripts/srkreload ]]; then
  echo "restore-backup-zip: requesting Asterisk reload"
  /bin/sh /opt/pbx3/scripts/srkreload || true
fi

echo "restore-backup-zip: OK — $(basename "$ZIP_PATH")"
echo "restore-backup-zip: do NOT run reloader.sh; run fleet onboard + LE Sync next."
