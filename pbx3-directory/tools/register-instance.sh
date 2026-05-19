#!/usr/bin/env bash
# Register or update a PBX instance in the org catalog + instances/{ksuid}/meta.json
#
# Requires: aws CLI, jq, IAM write on PBX3_ORG_BUCKET (not public catalog write).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./register-instance.sh \
#     --id 3DmAsxePTWQZgynBYXE8obIRqEE \
#     --fqdn 08jzwn.pbx3.com \
#     --api-base-url 'https://08jzwn.pbx3.com:44300/api' \
#     --label 08jzwn \
#     --environment production \
#     --org-id example-org \
#     --region us-east-1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

ID=""
FQDN=""
API_BASE_URL=""
LABEL=""
STATUS="active"
ENVIRONMENT=""
ORG_ID=""
REGION=""
NOTES=""
PACKAGE_VERSION=""

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID=$2; shift 2 ;;
    --fqdn) FQDN=$2; shift 2 ;;
    --api-base-url) API_BASE_URL=$2; shift 2 ;;
    --label) LABEL=$2; shift 2 ;;
    --status) STATUS=$2; shift 2 ;;
    --environment) ENVIRONMENT=$2; shift 2 ;;
    --org-id) ORG_ID=$2; shift 2 ;;
    --region) REGION=$2; shift 2 ;;
    --notes) NOTES=$2; shift 2 ;;
    --package-version) PACKAGE_VERSION=$2; shift 2 ;;
    --dry-run) export REGISTRAR_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

registrar_require_cmd
registrar_bucket >/dev/null

[[ -n "$ID" ]] || { echo "Missing --id (globals.id KSUID)" >&2; exit 1; }
[[ -n "$FQDN" ]] || { echo "Missing --fqdn" >&2; exit 1; }
[[ -n "$API_BASE_URL" ]] || { echo "Missing --api-base-url" >&2; exit 1; }
[[ -n "$LABEL" ]] || LABEL="$FQDN"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

RECORD="$WORKDIR/record.json"
jq -n \
  --arg id "$ID" \
  --arg fqdn "$FQDN" \
  --arg api_base_url "$API_BASE_URL" \
  --arg label "$LABEL" \
  --arg status "$STATUS" \
  --arg environment "$ENVIRONMENT" \
  --arg org_id "$ORG_ID" \
  --arg region "$REGION" \
  --arg notes "$NOTES" \
  --arg package_version "$PACKAGE_VERSION" \
  '{
    id: $id,
    fqdn: $fqdn,
    api_base_url: $api_base_url,
    label: $label,
    status: $status
  }
  + (if $environment != "" then {environment: $environment} else {} end)
  + (if $org_id != "" then {org_id: $org_id} else {} end)
  + (if $region != "" then {region: $region} else {} end)
  + (if $notes != "" then {notes: $notes} else {} end)
  + (if $package_version != "" then {package_version: $package_version} else {} end)' \
  >"$RECORD"

CATALOG="$WORKDIR/catalog.json"
registrar_fetch_catalog "$CATALOG"
registrar_upsert_catalog_instance "$CATALOG" "$RECORD"
registrar_publish_catalog "$CATALOG"

META_KEY="instances/${ID}/meta.json"
EXISTING_META="$WORKDIR/existing-meta.json"
META_OUT="$WORKDIR/meta.json"
registrar_s3_download "$META_KEY" "$EXISTING_META" || true
registrar_merge_instance_meta "$RECORD" "$EXISTING_META" "$META_OUT"
registrar_s3_cp "$META_OUT" "$META_KEY" --content-type application/json

echo "OK: instance $ID registered in s3://$(registrar_bucket)/$REGISTRAR_CATALOG_KEY and $META_KEY"
