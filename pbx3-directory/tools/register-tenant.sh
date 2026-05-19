#!/usr/bin/env bash
# Write tenants/{tenant_shortuid}/meta.json (required S3 prefix per tenant).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./register-tenant.sh \
#     --tenant-shortuid f34ck1 \
#     --instance-id 3DmAsxePTWQZgynBYXE8obIRqEE \
#     --cname f34ck1.pbx3.com \
#     --fqdn f34ck1.pbx3.com

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

TENANT_SHORTUID=""
INSTANCE_ID=""
CNAME=""
FQDN=""
STATUS="active"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant-shortuid) TENANT_SHORTUID=$2; shift 2 ;;
    --instance-id) INSTANCE_ID=$2; shift 2 ;;
    --cname) CNAME=$2; shift 2 ;;
    --fqdn) FQDN=$2; shift 2 ;;
    --status) STATUS=$2; shift 2 ;;
    --dry-run) export REGISTRAR_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

registrar_require_cmd
registrar_bucket >/dev/null

[[ -n "$TENANT_SHORTUID" ]] || { echo "Missing --tenant-shortuid" >&2; exit 1; }
[[ -n "$INSTANCE_ID" ]] || { echo "Missing --instance-id" >&2; exit 1; }
[[ -n "$CNAME" ]] || { echo "Missing --cname (tenant FQDN)" >&2; exit 1; }
[[ -n "$FQDN" ]] || FQDN="$CNAME"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

META_KEY="tenants/${TENANT_SHORTUID}/meta.json"
EXISTING="$WORKDIR/existing.json"
OUT="$WORKDIR/meta.json"
now=$(registrar_now_iso)
created=$now

if registrar_s3_download "$META_KEY" "$EXISTING"; then
  created=$(jq -r '.created_at // empty' "$EXISTING")
  [[ -z "$created" || "$created" == "null" ]] && created=$now
fi

jq -n \
  --arg tenant_shortuid "$TENANT_SHORTUID" \
  --arg instance_id "$INSTANCE_ID" \
  --arg cname "$CNAME" \
  --arg fqdn "$FQDN" \
  --arg status "$STATUS" \
  --arg created_at "$created" \
  --arg updated_at "$now" \
  '{
    tenant_shortuid: $tenant_shortuid,
    instance_id: $instance_id,
    cname: $cname,
    fqdn: $fqdn,
    status: $status,
    created_at: $created_at,
    updated_at: $updated_at,
    previous_instance_id: null
  }' >"$OUT"

# Preserve move history if re-registering same tenant
if [[ -f "$EXISTING" ]]; then
  jq -s '
    .[0] as $new | .[1] as $old |
    $new
    + (if $old.moved_at then {moved_at: $old.moved_at} else {} end)
    + (if $old.previous_instance_id then {previous_instance_id: $old.previous_instance_id} else {} end)
  ' "$OUT" "$EXISTING" >"${OUT}.merged"
  mv "${OUT}.merged" "$OUT"
fi

registrar_s3_cp "$OUT" "$META_KEY" --content-type application/json
echo "OK: tenant $TENANT_SHORTUID meta at s3://$(registrar_bucket)/$META_KEY"
