#!/usr/bin/env bash
# Compare fleet node cluster rows vs S3 tenants/*/meta.json (catalog HoR).
#
# Lab / Mode 4 guard: node-only tenants break B′ login (tenant-home) and fleet
# projection. Do not invent SQLite tenants on a fleet-joined box without Fleet
# Create / Gatekeeper provision / register-tenant.
#
# Usage (Mac/ops — not the node role):
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./reconcile-node-tenants.sh \
#     --ssh ubuntu@44.196.98.191 \
#     --ssh-key ~/Documents/pemfiles/pbx3test.pem
#
#   ./reconcile-node-tenants.sh ... --fix   # register node-only → catalog + rebuild tenant-home
#   ./reconcile-node-tenants.sh ... --include-default
#   ./reconcile-node-tenants.sh ... --strict-catalog   # also fail on catalog-only orphans
#
# Exit 0 = clean (or only catalog_only without --strict-catalog).
# Exit 1 = node_only and/or wrong_home (and catalog_only if --strict-catalog).
#
# Spec: pbx3-directory/docs/LAB_FLEET_TENANTS.md

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"
# shellcheck source=lib/onboard-common.sh
source "$SCRIPT_DIR/lib/onboard-common.sh"

DO_FIX=0
INCLUDE_DEFAULT=0
STRICT_CATALOG=0
FLEET_CONFIG=""
INSTANCE_KSUID=""

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) ONBOARD_SSH_TARGET=$2; shift 2 ;;
    --ssh-key) ONBOARD_SSH_KEY=$2; shift 2 ;;
    --ssh-user) ONBOARD_SSH_USER=$2; shift 2 ;;
    --region) ONBOARD_AWS_REGION=$2; shift 2 ;;
    --org-bucket) export PBX3_ORG_BUCKET=$2; shift 2 ;;
    --fleet-config) FLEET_CONFIG=$2; shift 2 ;;
    --instance-id) INSTANCE_KSUID=$2; shift 2 ;;
    --fix) DO_FIX=1; shift ;;
    --include-default) INCLUDE_DEFAULT=1; shift ;;
    --strict-catalog) STRICT_CATALOG=1; shift ;;
    --dry-run) export REGISTRAR_DRY_RUN=1; ONBOARD_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

onboard_require_cmd
registrar_require_cmd
command -v sqlite3 >/dev/null 2>&1 || true # node has sqlite3; local only needs jq/aws/ssh

if [[ -n "$FLEET_CONFIG" ]]; then
  onboard_load_fleet_config "$FLEET_CONFIG"
elif [[ -f "${HOME}/.pbx3/fleet.yaml" ]]; then
  onboard_load_fleet_config "${HOME}/.pbx3/fleet.yaml"
fi

[[ -n "${ONBOARD_SSH_TARGET:-}" ]] || {
  echo "reconcile-node-tenants: pass --ssh ubuntu@host" >&2
  exit 1
}

onboard_assert_ops_identity
BUCKET="$(registrar_bucket)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "reconcile-node-tenants: ssh=$ONBOARD_SSH_TARGET bucket=$BUCKET" >&2

# --- Node clusters ---
NODE_TSV="$WORKDIR/node.tsv"
onboard_ssh_read 'sudo sqlite3 -separator "|" /opt/pbx3/db/sqlite.db "SELECT shortuid, pkey, IFNULL(fqdn,\"\") FROM cluster WHERE shortuid IS NOT NULL AND TRIM(shortuid) != \"\";"' \
  >"$NODE_TSV" || true

if [[ -z "$INSTANCE_KSUID" ]]; then
  INSTANCE_KSUID="$(onboard_ssh_read 'sudo sqlite3 /opt/pbx3/db/sqlite.db "SELECT id FROM globals WHERE pkey='\''global'\'';"')"
fi
INSTANCE_KSUID="$(echo "$INSTANCE_KSUID" | tr -d '[:space:]')"
[[ -n "$INSTANCE_KSUID" ]] || {
  echo "reconcile-node-tenants: could not read globals.id from node" >&2
  exit 1
}
echo "reconcile-node-tenants: instance_id=$INSTANCE_KSUID" >&2

# --- Catalog metas ---
META_DIR="$WORKDIR/metas"
mkdir -p "$META_DIR"
aws_list=(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix tenants/ --delimiter '/')
[[ -n "${AWS_PROFILE:-}" ]] && aws_list+=(--profile "$AWS_PROFILE")
[[ -n "${ONBOARD_AWS_REGION:-}" ]] && aws_list+=(--region "$ONBOARD_AWS_REGION")

while IFS= read -r prefix; do
  [[ -z "$prefix" || "$prefix" == "None" ]] && continue
  shortuid="$(basename "${prefix%/}")"
  [[ -z "$shortuid" || "$shortuid" == _* ]] && continue
  registrar_s3_download "tenants/${shortuid}/meta.json" "$META_DIR/${shortuid}.json" || true
done < <("${aws_list[@]}" --query 'CommonPrefixes[].Prefix' --output text 2>/dev/null | tr '\t' '\n' || true)

NODE_JSON="$WORKDIR/node.json"
CAT_JSON="$WORKDIR/catalog.json"

{
  echo '['
  first=1
  while IFS='|' read -r su pk fq || [[ -n "${su:-}" ]]; do
    [[ -z "${su:-}" ]] && continue
    su="$(printf '%s' "$su" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    [[ -z "$su" ]] && continue
    if [[ "$INCLUDE_DEFAULT" -ne 1 && "${pk:-}" == "default" ]]; then
      continue
    fi
    [[ $first -eq 1 ]] || echo ','
    first=0
    jq -nc --arg s "$su" --arg p "${pk:-}" --arg f "${fq:-}" \
      '{shortuid:$s, pkey:$p, fqdn:$f}'
  done <"$NODE_TSV"
  echo ']'
} >"$WORKDIR/node_arr.json"
jq -n --slurpfile t "$WORKDIR/node_arr.json" '{tenants: $t[0]}' >"$NODE_JSON"

shopt -s nullglob
metas=("$META_DIR"/*.json)
if [[ ${#metas[@]} -eq 0 ]]; then
  jq -n --arg iid "$INSTANCE_KSUID" '{instance_id:$iid, tenants:[]}' >"$CAT_JSON"
else
  jq -s --arg iid "$INSTANCE_KSUID" '
    {
      instance_id: $iid,
      tenants: [
        .[]
        | select((.status // "active") | ascii_downcase != "decommissioned")
        | {
            shortuid: ((.shortuid // .tenant_shortuid // "") | ascii_downcase | gsub("^\\s+|\\s+$";"")),
            instance_id: ((.instance_id // "") | gsub("^\\s+|\\s+$";"")),
            cname: ((.cname // .fqdn // "") | gsub("^\\s+|\\s+$";"")),
            pkey: ((.pkey // .label // "") | tostring)
          }
        | select(.shortuid != "" and .instance_id != "")
      ]
    }
  ' "${metas[@]}" >"$CAT_JSON"
fi

REPORT="$WORKDIR/report.json"
jq -n --slurpfile node "$NODE_JSON" --slurpfile cat "$CAT_JSON" --arg iid "$INSTANCE_KSUID" '
  ($node[0].tenants // []) as $n
  | ($cat[0].tenants // []) as $all
  | ($all | map(select(.instance_id == $iid))) as $here
  | ($all | map(select(.instance_id != $iid))) as $elsewhere
  | ($n | map(.shortuid) | unique) as $ns
  | ($here | map(.shortuid) | unique) as $hs
  | {
      instance_id: $iid,
      ok: [ $n[] | select(.shortuid as $s | ($hs | index($s)) != null) ],
      node_only: [ $n[] | select(.shortuid as $s | ($hs | index($s)) == null) ],
      catalog_only: [ $here[] | select(.shortuid as $s | ($ns | index($s)) == null) ],
      wrong_home: [
        $n[] as $row
        | ($elsewhere[] | select(.shortuid == $row.shortuid)) as $m
        | select($m != null)
        | {shortuid: $row.shortuid, node_pkey: $row.pkey, catalog_instance_id: $m.instance_id}
      ]
    }
' >"$REPORT"

echo "=== reconcile-node-tenants report ==="
jq '{
  instance_id,
  ok: (.ok | map(.shortuid)),
  node_only: (.node_only | map(.shortuid)),
  catalog_only: (.catalog_only | map(.shortuid)),
  wrong_home: (.wrong_home | map(.shortuid))
}' "$REPORT"

node_only_n="$(jq '.node_only | length' "$REPORT")"
wrong_n="$(jq '.wrong_home | length' "$REPORT")"
catalog_only_n="$(jq '.catalog_only | length' "$REPORT")"

if [[ "$DO_FIX" -eq 1 && "$node_only_n" -gt 0 ]]; then
  echo "reconcile-node-tenants: --fix registering $node_only_n node-only tenant(s)" >&2
  while IFS= read -r su; do
    [[ -z "$su" ]] && continue
    cname="$(jq -r --arg s "$su" '.node_only[] | select(.shortuid==$s) | .fqdn // empty' "$REPORT")"
    [[ -z "$cname" || "$cname" == "null" ]] && cname="${su}.pbx3.com"
    echo "  register-tenant $su → $INSTANCE_KSUID ($cname)" >&2
    if [[ "${REGISTRAR_DRY_RUN:-0}" == "1" ]]; then
      echo "  DRY-RUN: register-tenant.sh --tenant-shortuid $su ..." >&2
      continue
    fi
    "$SCRIPT_DIR/register-tenant.sh" \
      --tenant-shortuid "$su" \
      --instance-id "$INSTANCE_KSUID" \
      --cname "$cname" \
      --fqdn "$cname"
  done < <(jq -r '.node_only[].shortuid' "$REPORT")
  # register-tenant already rebuilds tenant-home; ensure once more if all dry-run skipped
  if [[ "${REGISTRAR_DRY_RUN:-0}" != "1" ]]; then
    "$SCRIPT_DIR/rebuild-tenant-home.sh" || true
  fi
  echo "reconcile-node-tenants: fix done — re-run without --fix to verify" >&2
  exit 0
fi

fail=0
if [[ "$node_only_n" -gt 0 ]]; then
  echo "FAIL: $node_only_n node-only tenant(s) (not in catalog for this instance). Fleet Create or: $0 ... --fix" >&2
  fail=1
fi
if [[ "$wrong_n" -gt 0 ]]; then
  echo "FAIL: $wrong_n tenant(s) on this node but catalog meta points elsewhere (move or fix meta)." >&2
  fail=1
fi
if [[ "$STRICT_CATALOG" -eq 1 && "$catalog_only_n" -gt 0 ]]; then
  echo "FAIL: $catalog_only_n catalog-only tenant(s) claimed for this instance but missing on node." >&2
  fail=1
elif [[ "$catalog_only_n" -gt 0 ]]; then
  echo "WARN: $catalog_only_n catalog-only tenant(s) for this instance (not on node). Import or decommission meta." >&2
fi

if [[ "$fail" -eq 0 ]]; then
  echo "OK: node tenants match catalog for instance $INSTANCE_KSUID" >&2
fi
exit "$fail"
