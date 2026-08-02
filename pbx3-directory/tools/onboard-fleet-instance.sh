#!/usr/bin/env bash
# Onboard a PBX EC2 instance into an existing fleet (S6.4).
#
# Prerequisites: node installed from fleet-ready AMI, /up returns 200, SSH works.
# Run from Mac/ops with IAM admin (not from the EC2 node role).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./onboard-fleet-instance.sh \
#     --instance-id i-0bb601e7b1253c3f5 \
#     --ssh ubuntu@bzy54n.pbx3.com \
#     --ssh-key {path to your pemfiles}/key.pem \
#     --region us-east-1
#
# Optional fleet defaults: ~/.pbx3/fleet.yaml or --fleet-config PATH
#   org_bucket: 08jzwn-pbx3
#   region: us-east-1
#   ssh_user: ubuntu
#   ssh_key: {path to your pemfiles}/key.pem
#   org_id: example-org
#   environment: production
#   sbc_egress_host: sbc.pbx3.com
#
# After catalog/.env: seeds trunks.pkey=Egress (mandatory fleet dial-plane), runs
# genAst + asterisk restart. Override host: PBX3_SBC_EGRESS_HOST or --sbc-egress-host.
# Failover: PBX3_SBC_EGRESS_FAILOVER_HOST. Skip seed: --skip-egress-seed (unusual).
# Edge domain/dispatcher cutover on the SBC remains a separate ops step.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/onboard-common.sh
source "$SCRIPT_DIR/lib/onboard-common.sh"

ONBOARD_SCHEMA_DIR="$(cd "$SCRIPT_DIR/../schema" && pwd)"
INSTANCE_ID=""
FLEET_CONFIG=""
SKIP_IAM=0
SKIP_CATALOG=0
SKIP_NODE=0
SKIP_EGRESS_SEED=0
ONBOARD_GIT_PULL=0
SMOKE_BACKUP=0
ONBOARD_ORG_ID="${ONBOARD_ORG_ID:-example-org}"
ONBOARD_ENVIRONMENT="${ONBOARD_ENVIRONMENT:-production}"
ONBOARD_NOTES="${ONBOARD_NOTES:-}"

usage() {
  sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance-id) INSTANCE_ID=$2; shift 2 ;;
    --ssh) ONBOARD_SSH_TARGET=$2; shift 2 ;;
    --ssh-key) ONBOARD_SSH_KEY=$2; shift 2 ;;
    --ssh-user) ONBOARD_SSH_USER=$2; shift 2 ;;
    --region) ONBOARD_AWS_REGION=$2; shift 2 ;;
    --org-bucket) export PBX3_ORG_BUCKET=$2; shift 2 ;;
    --org-id) ONBOARD_ORG_ID=$2; shift 2 ;;
    --environment) ONBOARD_ENVIRONMENT=$2; shift 2 ;;
    --notes) ONBOARD_NOTES=$2; shift 2 ;;
    --api-port) ONBOARD_API_PORT=$2; shift 2 ;;
    --fleet-config) FLEET_CONFIG=$2; shift 2 ;;
    --sbc-egress-host) export PBX3_SBC_EGRESS_HOST=$2; shift 2 ;;
    --git-pull) ONBOARD_GIT_PULL=1; shift ;;
    --smoke-backup) SMOKE_BACKUP=1; shift ;;
    --skip-iam) SKIP_IAM=1; shift ;;
    --skip-catalog) SKIP_CATALOG=1; shift ;;
    --skip-node) SKIP_NODE=1; shift ;;
    --skip-egress-seed) SKIP_EGRESS_SEED=1; shift ;;
    --dry-run) ONBOARD_DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

onboard_require_cmd
onboard_assert_ops_identity

[[ -n "${FLEET_CONFIG:-}" ]] && onboard_load_fleet_config "$FLEET_CONFIG"
[[ -f "${HOME}/.pbx3/fleet.yaml" ]] && onboard_load_fleet_config "${HOME}/.pbx3/fleet.yaml"

if [[ -z "${PBX3_ORG_BUCKET:-}" ]]; then
  onboard_log "set PBX3_ORG_BUCKET or org_bucket in fleet config"
  exit 1
fi

if [[ -z "$ONBOARD_AWS_REGION" ]]; then
  ONBOARD_AWS_REGION="$(onboard_aws_read configure get region 2>/dev/null || true)"
  ONBOARD_AWS_REGION="${ONBOARD_AWS_REGION:-us-east-1}"
fi

[[ -n "$INSTANCE_ID" ]] || { onboard_log "Missing --instance-id (required for IAM attach)"; exit 1; }

if [[ -z "$ONBOARD_SSH_TARGET" ]]; then
  onboard_resolve_ssh_from_instance "$INSTANCE_ID"
fi

if [[ "$SKIP_NODE" == "0" && -z "$ONBOARD_SSH_TARGET" ]]; then
  onboard_log "Missing --ssh user@host (or resolvable public IP on instance)"
  exit 1
fi

onboard_log "fleet bucket: $PBX3_ORG_BUCKET region: $ONBOARD_AWS_REGION instance: $INSTANCE_ID"

# --- Discover identity from node (source of truth) ---
if [[ "$SKIP_NODE" == "0" || "$SKIP_IAM" == "0" || "$SKIP_CATALOG" == "0" ]]; then
  onboard_discover_globals
fi

API_BASE_URL="https://${ONBOARD_FQDN}:${ONBOARD_API_PORT}/api"

# --- IAM ---
if [[ "$SKIP_IAM" == "0" ]]; then
  onboard_log "step: IAM"
  onboard_iam_provision "$INSTANCE_ID" "$ONBOARD_SHORTUID" "$ONBOARD_KSUID" "$PBX3_ORG_BUCKET"
else
  onboard_log "step: IAM (skipped)"
fi

# --- Catalog ---
if [[ "$SKIP_CATALOG" == "0" ]]; then
  onboard_log "step: catalog"
  REG_ARGS=(
  "$SCRIPT_DIR/register-instance.sh"
  --id "$ONBOARD_KSUID"
  --fqdn "$ONBOARD_FQDN"
  --api-base-url "$API_BASE_URL"
  --label "$ONBOARD_SHORTUID"
  --status active
  --environment "$ONBOARD_ENVIRONMENT"
  --org-id "$ONBOARD_ORG_ID"
  --region "$ONBOARD_AWS_REGION"
  )
  [[ -n "$ONBOARD_NOTES" ]] && REG_ARGS+=(--notes "$ONBOARD_NOTES")
  [[ "$ONBOARD_DRY_RUN" == "1" ]] && REG_ARGS+=(--dry-run)
  "${REG_ARGS[@]}"
else
  onboard_log "step: catalog (skipped)"
fi

# --- Node .env + S3 smoke ---
if [[ "$SKIP_NODE" == "0" ]]; then
  onboard_log "step: node configure"
  onboard_configure_node "$PBX3_ORG_BUCKET" "$ONBOARD_KSUID"
else
  onboard_log "step: node configure (skipped)"
fi

# --- Fleet Egress trunk (mandatory for fleet dial-plane) ---
if [[ "$SKIP_NODE" == "0" && "${SKIP_EGRESS_SEED:-0}" == "0" ]]; then
  onboard_seed_egress_trunk
else
  onboard_log "step: fleet Egress seed (skipped)"
fi

# --- Verify catalog ---
if [[ "$SKIP_CATALOG" == "0" ]]; then
  onboard_verify_catalog "$ONBOARD_KSUID" "$PBX3_ORG_BUCKET"
fi

# --- Optional backup upload smoke ---
if [[ "$SMOKE_BACKUP" == "1" && "$SKIP_NODE" == "0" ]]; then
  onboard_log "step: backup upload smoke"
  if [[ "$ONBOARD_DRY_RUN" == "1" ]]; then
    onboard_log "DRY-RUN: would run pbx3:upload-backup on node if zip exists"
  else
    onboard_ssh_write "bash -s" <<'REMOTE'
set -e
ZIP=$(ls -t /opt/pbx3/bkup/pbx3bak.*.zip 2>/dev/null | head -1 || true)
if [[ -z "$ZIP" ]]; then
  echo "no local backup zip — skip upload smoke"
  exit 0
fi
cd /opt/pbx3api
sudo php artisan pbx3:upload-backup "$(basename "$ZIP")"
REMOTE
  fi
fi

onboard_log "OK: ${ONBOARD_SHORTUID} (${ONBOARD_KSUID}) onboarded to s3://${PBX3_ORG_BUCKET}"
onboard_log "SPA: refresh catalog to see ${ONBOARD_SHORTUID} · ${ONBOARD_FQDN}"
