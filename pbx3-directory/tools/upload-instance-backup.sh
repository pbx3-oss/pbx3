#!/usr/bin/env bash
# Phase 4: upload one local backup zip to instances/{ksuid}/backups/{stamp}/ on PBX3_ORG_BUCKET.
# Use when pbx3api Flysystem is not installed yet, or to retry a failed upload.
#
# Requires: aws, jq, PBX3_ORG_BUCKET, globals.id + fqdn (from sqlite or args).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "${SCRIPT_DIR}/lib/registrar-common.sh"

usage() {
  cat <<'EOF'
Usage: upload-instance-backup.sh --zip PATH [--instance-id KSUID] [--fqdn FQDN] [--trigger manual]

  --zip PATH           Local file (e.g. /opt/pbx3/bkup/pbx3bak.1716123456.zip)
  --instance-id KSUID  defaults: globals.id from /opt/pbx3/db/instance.db
  --fqdn FQDN          defaults: globals.fqdn from sqlite
  --trigger TYPE       manual | scheduled | pre-upgrade (default: manual)
EOF
}

ZIP_PATH=""
INSTANCE_ID=""
FQDN=""
TRIGGER="manual"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zip) ZIP_PATH=$2; shift 2 ;;
    --instance-id) INSTANCE_ID=$2; shift 2 ;;
    --fqdn) FQDN=$2; shift 2 ;;
    --trigger) TRIGGER=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
  echo "upload-instance-backup: --zip must point to an existing file" >&2
  exit 1
fi

BASENAME="$(basename "$ZIP_PATH")"
if [[ ! "$BASENAME" =~ ^pbx3bak\.([0-9]+)\.zip$ ]]; then
  echo "upload-instance-backup: expected pbx3bak.{unixtime}.zip, got: $BASENAME" >&2
  exit 1
fi
EPOCH="${BASH_REMATCH[1]}"
STAMP="$(date -u -r "$EPOCH" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u -d "@$EPOCH" +%Y%m%dT%H%M%SZ)"
CREATED_AT="$(date -u -r "$EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$EPOCH" +%Y-%m-%dT%H:%M:%SZ)"

DB_PATH="${PBX3_INSTANCE_DB:-/opt/pbx3/db/instance.db}"
if [[ -z "$INSTANCE_ID" && -f "$DB_PATH" ]]; then
  INSTANCE_ID="$(sqlite3 "$DB_PATH" "SELECT id FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null || true)"
  if [[ -z "$INSTANCE_ID" ]]; then
    INSTANCE_ID="$(sqlite3 "$DB_PATH" "SELECT pkey FROM globals WHERE pkey!='global' AND length(pkey)=27 LIMIT 1;" 2>/dev/null || true)"
  fi
fi
if [[ -z "$FQDN" && -f "$DB_PATH" ]]; then
  FQDN="$(sqlite3 "$DB_PATH" "SELECT fqdn FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null || true)"
fi

if [[ -z "$INSTANCE_ID" ]]; then
  echo "upload-instance-backup: set --instance-id or ensure $DB_PATH has globals.id" >&2
  exit 1
fi

registrar_require_cmd
BUCKET="$(registrar_bucket)"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
BYTES="$(wc -c <"$ZIP_PATH" | tr -d ' ')"

PBX3_VERSION="unknown"
if command -v dpkg-query >/dev/null 2>&1; then
  v="$(dpkg-query -W -f='${Version}' pbx3 2>/dev/null || true)"
  [[ -n "$v" ]] && PBX3_VERSION="pbx3 ${v}"
fi

ZIP_ENTRIES=0
if command -v zipinfo >/dev/null 2>&1; then
  ZIP_ENTRIES="$(zipinfo -t "$ZIP_PATH" 2>/dev/null | awk '/^Total files/ {print $3}' || echo 0)"
fi

PREFIX="instances/${INSTANCE_ID}/backups"
STAMP_PREFIX="${PREFIX}/${STAMP}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MANIFEST="${TMP}/manifest.json"
jq -n \
  --arg created "$CREATED_AT" \
  --arg instance "$INSTANCE_ID" \
  --arg fqdn "$FQDN" \
  --arg ver "$PBX3_VERSION" \
  --arg trigger "$TRIGGER" \
  --arg sha "$SHA256" \
  --argjson bytes "$BYTES" \
  --argjson entries "$ZIP_ENTRIES" \
  '{
    schema_version: 1,
    created_at: $created,
    scope: "instance",
    trigger: $trigger,
    instance_id: $instance,
    tenant_shortuid: null,
    node_fqdn: $fqdn,
    pbx3_version: $ver,
    contents_summary: {zip_entries: $entries},
    artifacts: [{name: "backup.zip", sha256: $sha, bytes: $bytes}]
  }' >"$MANIFEST"

registrar_s3_cp "$ZIP_PATH" "${STAMP_PREFIX}/backup.zip" --content-type application/zip
registrar_s3_cp "$MANIFEST" "${STAMP_PREFIX}/manifest.json" --content-type application/json

POLICY_KEY="${PREFIX}/policy.json"
if [[ "${REGISTRAR_DRY_RUN:-0}" != "1" ]]; then
  if ! aws s3api head-object --bucket "$BUCKET" --key "$POLICY_KEY" "${AWS_PROFILE:+--profile $AWS_PROFILE}" >/dev/null 2>&1; then
    jq -n '{maxage_days: 30, glacier_after_days: 0, legal_hold: false}' >"${TMP}/policy.json"
    registrar_s3_cp "${TMP}/policy.json" "$POLICY_KEY" --content-type application/json
  fi
fi

META_KEY="instances/${INSTANCE_ID}/meta.json"
META_FILE="${TMP}/meta.json"
NOW="$(registrar_now_iso)"
if registrar_s3_download "$META_KEY" "$META_FILE"; then
  jq --arg stamp "$STAMP" --arg now "$NOW" \
    '.backup_latest_stamp = $stamp | .updated_at = $now' "$META_FILE" >"${TMP}/meta-out.json"
else
  LABEL="${FQDN%%.*}"
  [[ -z "$LABEL" ]] && LABEL="$INSTANCE_ID"
  jq -n \
    --arg id "$INSTANCE_ID" \
    --arg fqdn "$FQDN" \
    --arg label "$LABEL" \
    --arg api "https://${FQDN}:44300/api" \
    --arg stamp "$STAMP" \
    --arg now "$NOW" \
    '{
      id: $id,
      fqdn: $fqdn,
      api_base_url: $api,
      label: $label,
      status: "active",
      created_at: $now,
      updated_at: $now,
      backup_latest_stamp: $stamp
    }' >"${TMP}/meta-out.json"
fi
registrar_s3_cp "${TMP}/meta-out.json" "$META_KEY" --content-type application/json

echo "upload-instance-backup: s3://${BUCKET}/${STAMP_PREFIX}/backup.zip"
