#!/usr/bin/env bash
# Rebuild catalog/tenant-home.json from tenants/*/meta.json (B′ login rollup).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./rebuild-tenant-home.sh
#   ./rebuild-tenant-home.sh --dry-run

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

REGISTRAR_TENANT_HOME_KEY="${REGISTRAR_TENANT_HOME_KEY:-catalog/tenant-home.json}"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) export REGISTRAR_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

registrar_require_cmd
BUCKET=$(registrar_bucket)
now=$(registrar_now_iso)
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

META_DIR="$WORKDIR/metas"
mkdir -p "$META_DIR"
OUT="$WORKDIR/tenant-home.json"

if [[ "${REGISTRAR_DRY_RUN:-0}" == "1" ]]; then
  echo "DRY-RUN: would list s3://$BUCKET/tenants/ and write $REGISTRAR_TENANT_HOME_KEY" >&2
  exit 0
fi

aws_list=(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix tenants/ --delimiter '/')
[[ -n "${AWS_PROFILE:-}" ]] && aws_list+=(--profile "$AWS_PROFILE")

prefixes=()
while IFS= read -r prefix; do
  [[ -z "$prefix" || "$prefix" == "None" ]] && continue
  prefixes+=("$prefix")
done < <("${aws_list[@]}" --query 'CommonPrefixes[].Prefix' --output text | tr '\t' '\n' || true)

for prefix in "${prefixes[@]:-}"; do
  [[ -z "$prefix" || "$prefix" == "None" ]] && continue
  shortuid=$(basename "${prefix%/}")
  [[ -z "$shortuid" || "$shortuid" == _* ]] && continue
  registrar_s3_download "tenants/${shortuid}/meta.json" "$META_DIR/${shortuid}.json" || true
done

shopt -s nullglob
metas=("$META_DIR"/*.json)
if [[ ${#metas[@]} -eq 0 ]]; then
  jq -n --arg now "$now" '{version: 1, updated_at: $now, tenants: []}' >"$OUT"
else
  jq -s --arg now "$now" '
    [
      .[]
      | select((.status // "active") | ascii_downcase != "decommissioned")
      | {
          shortuid: ((.shortuid // .tenant_shortuid // "") | ascii_downcase | gsub("^\\s+|\\s+$";"")),
          instance_id: ((.instance_id // "") | gsub("^\\s+|\\s+$";"")),
          cname: ((.cname // .fqdn // .shortuid // .tenant_shortuid // "") | gsub("^\\s+|\\s+$";""))
        }
      | select(.shortuid != "" and .instance_id != "")
      | .cname = (if .cname == "" then .shortuid else .cname end)
    ]
    | sort_by(.shortuid)
    | {version: 1, updated_at: $now, tenants: .}
  ' "${metas[@]}" >"$OUT"
fi

registrar_s3_cp "$OUT" "$REGISTRAR_TENANT_HOME_KEY" \
  --content-type application/json \
  --cache-control 'no-cache, max-age=0'
count=$(jq '.tenants | length' "$OUT")
echo "OK: wrote $REGISTRAR_TENANT_HOME_KEY ($count tenants)"
