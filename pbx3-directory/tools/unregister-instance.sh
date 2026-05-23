#!/usr/bin/env bash
# Remove an instance from the fleet directory (catalog + meta status).
#
# Default: soft decommission — sets status=decommissioned (hidden from SPA picker).
# --remove: delete the catalog row entirely (meta.json kept for S3 backup history).
#
# Does NOT: delete S3 backups, detach IAM, or stop the PBX node. See docs.
#
# Requires: aws CLI, jq, IAM write on PBX3_ORG_BUCKET (same as register-instance.sh).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./unregister-instance.sh --id 3E3gAOVGBhvc6vEPTBIYCBPycIk
#   ./unregister-instance.sh --id 3E3gAOVGBhvc6vEPTBIYCBPycIk --remove --notes 'EC2 terminated'

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

ID=""
REMOVE=0
NOTES=""

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID=$2; shift 2 ;;
    --remove) REMOVE=1; shift ;;
    --notes) NOTES=$2; shift 2 ;;
    --dry-run) export REGISTRAR_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

registrar_require_cmd
registrar_bucket >/dev/null

[[ -n "$ID" ]] || { echo "Missing --id (globals.id KSUID)" >&2; exit 1; }

if [[ -z "$NOTES" ]]; then
  if [[ "$REMOVE" == "1" ]]; then
    NOTES="Removed from fleet catalog $(date -u +%Y-%m-%d)"
  else
    NOTES="Decommissioned $(date -u +%Y-%m-%d)"
  fi
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

CATALOG="$WORKDIR/catalog.json"
registrar_fetch_catalog "$CATALOG"

EXISTING="$(registrar_find_catalog_instance "$CATALOG" "$ID")"
[[ -n "$EXISTING" ]] || { echo "Instance $ID not found in catalog" >&2; exit 1; }

if [[ "$REMOVE" == "1" ]]; then
  registrar_remove_catalog_instance "$CATALOG" "$ID"
  ACTION="removed from catalog"
else
  registrar_decommission_catalog_instance "$CATALOG" "$ID" "$NOTES"
  ACTION="decommissioned in catalog"
fi

registrar_publish_catalog "$CATALOG"

META_KEY="instances/${ID}/meta.json"
EXISTING_META="$WORKDIR/existing-meta.json"
META_OUT="$WORKDIR/meta.json"
registrar_s3_download "$META_KEY" "$EXISTING_META" || true

if [[ -f "$EXISTING_META" ]]; then
  now=$(registrar_now_iso)
  if [[ "$REMOVE" == "1" ]]; then
    jq --arg now "$now" --arg notes "$NOTES" '
      .status = "decommissioned" | .updated_at = $now | .notes = $notes
    ' "$EXISTING_META" >"$META_OUT"
  else
    jq --arg now "$now" --arg notes "$NOTES" '
      .status = "decommissioned" | .updated_at = $now | .notes = $notes
    ' "$EXISTING_META" >"$META_OUT"
  fi
  registrar_s3_cp "$META_OUT" "$META_KEY" --content-type application/json
else
  echo "Note: no $META_KEY in bucket (catalog updated only)" >&2
fi

echo "OK: instance $ID $ACTION in s3://$(registrar_bucket)/$REGISTRAR_CATALOG_KEY"
if [[ "$REMOVE" != "1" ]]; then
  echo "SPA: instance hidden from picker (status=decommissioned). Refresh catalog."
fi
