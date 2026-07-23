#!/usr/bin/env bash
# Update tenant meta when moving to another instance (does not move recordings prefix).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./move-tenant.sh \
#     --tenant-shortuid f34ck1 \
#     --instance-id NEW_KSUID \
#     --cname f34ck1.pbx3.com

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
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
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
[[ -n "$INSTANCE_ID" ]] || { echo "Missing --instance-id (new hosting node)" >&2; exit 1; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

META_KEY="tenants/${TENANT_SHORTUID}/meta.json"
EXISTING="$WORKDIR/existing.json"
OUT="$WORKDIR/meta.json"

if ! registrar_s3_download "$META_KEY" "$EXISTING"; then
  echo "No existing meta at $META_KEY — use register-tenant.sh first" >&2
  exit 1
fi

CNAME="${CNAME:-$(jq -r '.cname // .fqdn' "$EXISTING")}"
FQDN="${FQDN:-$CNAME}"
now=$(registrar_now_iso)
prev=$(jq -r '.instance_id' "$EXISTING")

if [[ "$prev" == "$INSTANCE_ID" ]]; then
  echo "Tenant already on instance $INSTANCE_ID — no change" >&2
  exit 0
fi

jq \
  --arg instance_id "$INSTANCE_ID" \
  --arg cname "$CNAME" \
  --arg fqdn "$FQDN" \
  --arg status "$STATUS" \
  --arg moved_at "$now" \
  --arg updated_at "$now" \
  --arg previous_instance_id "$prev" \
  '.instance_id = $instance_id
   | .cname = $cname
   | .fqdn = $fqdn
   | .status = $status
   | .moved_at = $moved_at
   | .updated_at = $updated_at
   | .previous_instance_id = $previous_instance_id' \
  "$EXISTING" >"$OUT"

registrar_s3_cp "$OUT" "$META_KEY" --content-type application/json
echo "OK: tenant $TENANT_SHORTUID moved $prev -> $INSTANCE_ID (recordings prefix unchanged)"

# B′ login rollup (best-effort — do not fail the move if rebuild flakes)
if [[ -x "$SCRIPT_DIR/rebuild-tenant-home.sh" ]]; then
  "$SCRIPT_DIR/rebuild-tenant-home.sh" || echo "WARN: rebuild-tenant-home.sh failed — run it manually" >&2
fi
