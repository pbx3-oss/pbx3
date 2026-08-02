# shellcheck shell=bash
# Shared helpers for onboard-fleet-instance.sh (S6.4).

set -euo pipefail

ONBOARD_DRY_RUN="${ONBOARD_DRY_RUN:-0}"
ONBOARD_API_PORT="${ONBOARD_API_PORT:-44300}"
ONBOARD_SSH_USER="${ONBOARD_SSH_USER:-ubuntu}"
ONBOARD_SSH_KEY="${ONBOARD_SSH_KEY:-}"
ONBOARD_SSH_TARGET="${ONBOARD_SSH_TARGET:-}"
ONBOARD_AWS_REGION="${ONBOARD_AWS_REGION:-}"

onboard_log() {
  printf 'onboard: %s\n' "$*" >&2
}

onboard_require_cmd() {
  local cmd
  for cmd in aws jq ssh scp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      onboard_log "required command not found: $cmd"
      exit 1
    fi
  done
}

onboard_aws_read() {
  local -a cmd=(aws)
  [[ -n "${AWS_PROFILE:-}" ]] && cmd+=(--profile "$AWS_PROFILE")
  [[ -n "$ONBOARD_AWS_REGION" ]] && cmd+=(--region "$ONBOARD_AWS_REGION")
  cmd+=("$@")
  "${cmd[@]}"
}

onboard_aws_write() {
  local -a cmd=(aws)
  [[ -n "${AWS_PROFILE:-}" ]] && cmd+=(--profile "$AWS_PROFILE")
  [[ -n "$ONBOARD_AWS_REGION" ]] && cmd+=(--region "$ONBOARD_AWS_REGION")
  cmd+=("$@")
  if [[ "$ONBOARD_DRY_RUN" == "1" ]]; then
    onboard_log "DRY-RUN: ${cmd[*]}"
    return 0
  fi
  "${cmd[@]}"
}

onboard_assert_ops_identity() {
  local arn
  arn="$(onboard_aws_read sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
  if [[ "$arn" == *":assumed-role/pbx3-node-"* ]]; then
    onboard_log "AWS identity is a PBX EC2 node role ($arn)."
    onboard_log "Run from your Mac (or ops workstation) with IAM admin credentials."
    exit 1
  fi
  [[ -n "$arn" ]] || { onboard_log "aws sts get-caller-identity failed"; exit 1; }
  onboard_log "AWS identity: $arn"
}

onboard_load_fleet_config() {
  local file=$1
  [[ -f "$file" ]] || return 0
  onboard_log "loading fleet config: $file"
  # Simple key: value (no nested YAML parser required).
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue
    key="${line%%:*}"
    val="${line#*:}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    case "$key" in
      org_bucket) [[ -z "${PBX3_ORG_BUCKET:-}" ]] && export PBX3_ORG_BUCKET="$val" ;;
      region) [[ -z "$ONBOARD_AWS_REGION" ]] && ONBOARD_AWS_REGION="$val" ;;
      ssh_user) [[ "$ONBOARD_SSH_USER" == "ubuntu" ]] && ONBOARD_SSH_USER="$val" ;;
      ssh_key) [[ -z "$ONBOARD_SSH_KEY" ]] && ONBOARD_SSH_KEY="$val" ;;
      org_id) [[ -z "${ONBOARD_ORG_ID:-}" ]] && export ONBOARD_ORG_ID="$val" ;;
      environment) [[ -z "${ONBOARD_ENVIRONMENT:-}" ]] && export ONBOARD_ENVIRONMENT="$val" ;;
      sbc_egress_host) [[ -z "${PBX3_SBC_EGRESS_HOST:-}" ]] && export PBX3_SBC_EGRESS_HOST="$val" ;;
    esac
  done <"$file"
}

onboard_ssh_opts() {
  ONBOARD_SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
  if [[ -n "$ONBOARD_SSH_KEY" ]]; then
    ONBOARD_SSH_OPTS+=(-i "$ONBOARD_SSH_KEY")
  fi
}

onboard_ssh_read() {
  onboard_ssh_opts
  ssh "${ONBOARD_SSH_OPTS[@]}" "$ONBOARD_SSH_TARGET" "$@"
}

onboard_ssh_write() {
  onboard_ssh_opts
  if [[ "$ONBOARD_DRY_RUN" == "1" ]]; then
    onboard_log "DRY-RUN: ssh ${ONBOARD_SSH_OPTS[*]} $ONBOARD_SSH_TARGET $*"
    return 0
  fi
  ssh "${ONBOARD_SSH_OPTS[@]}" "$ONBOARD_SSH_TARGET" "$@"
}

onboard_resolve_ssh_from_instance() {
  local instance_id=$1
  local ip
  ip="$(onboard_aws_read ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || true)"
  if [[ -z "$ip" || "$ip" == "None" || "$ip" == "null" ]]; then
    onboard_log "Could not resolve public IP for $instance_id — pass --ssh user@host"
    exit 1
  fi
  ONBOARD_SSH_TARGET="${ONBOARD_SSH_USER}@${ip}"
  onboard_log "resolved SSH target: $ONBOARD_SSH_TARGET"
}

onboard_discover_globals() {
  local line shortuid fqdn ksuid up_code
  line="$(onboard_ssh_read "sqlite3 /opt/pbx3/db/sqlite.db \"SELECT shortuid, fqdn, id FROM globals WHERE pkey='global';\"")"
  IFS='|' read -r shortuid fqdn ksuid <<<"$line"
  [[ -n "$shortuid" && -n "$fqdn" && -n "$ksuid" ]] || {
    onboard_log "failed to read globals from node (got: $line)"
    exit 1
  }
  up_code="$(onboard_ssh_read "curl -k -sS -o /dev/null -w '%{http_code}' https://127.0.0.1:${ONBOARD_API_PORT}/up 2>/dev/null || echo 000")"
  [[ "$up_code" == "200" ]] || {
    onboard_log "/up returned HTTP $up_code (expected 200) — fix node health before onboarding"
    exit 1
  }
  ONBOARD_SHORTUID="$shortuid"
  ONBOARD_FQDN="$fqdn"
  ONBOARD_KSUID="$ksuid"
  onboard_log "discovered shortuid=$shortuid fqdn=$fqdn ksuid=$ksuid"
}

onboard_render_policy() {
  local bucket=$1 ksuid=$2 dest=$3
  local tmpl="${ONBOARD_SCHEMA_DIR}/pbx3-node-s3-writer.policy.json.tmpl"
  [[ -f "$tmpl" ]] || { onboard_log "policy template not found: $tmpl"; exit 1; }
  sed -e "s/__BUCKET__/${bucket}/g" -e "s/__INSTANCE_KSUID__/${ksuid}/g" "$tmpl" >"$dest"
}

onboard_iam_provision() {
  local instance_id=$1 shortuid=$2 ksuid=$3 bucket=$4
  local role="pbx3-node-${shortuid}"
  local profile="pbx3-node-${shortuid}"
  local policy_name="pbx3-node-${shortuid}-s3-writer"
  local account policy_arn trust workdir policy_file

  account="$(onboard_aws_read sts get-caller-identity --query Account --output text)"
  policy_arn="arn:aws:iam::${account}:policy/${policy_name}"
  trust='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

  workdir="$(mktemp -d)"
  policy_file="$workdir/policy.json"
  onboard_render_policy "$bucket" "$ksuid" "$policy_file"

  if onboard_aws_read iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
    onboard_log "updating IAM policy $policy_name"
    onboard_aws_write iam create-policy-version \
      --policy-arn "$policy_arn" \
      --policy-document "file://${policy_file}" \
      --set-as-default
  else
    onboard_log "creating IAM policy $policy_name"
    onboard_aws_write iam create-policy \
      --policy-name "$policy_name" \
      --policy-document "file://${policy_file}"
  fi

  if ! onboard_aws_read iam get-role --role-name "$role" >/dev/null 2>&1; then
    onboard_log "creating IAM role $role"
    onboard_aws_write iam create-role --role-name "$role" --assume-role-policy-document "$trust"
  fi
  onboard_aws_write iam attach-role-policy --role-name "$role" --policy-arn "$policy_arn" 2>/dev/null || true

  if ! onboard_aws_read iam get-instance-profile --instance-profile-name "$profile" >/dev/null 2>&1; then
    onboard_log "creating instance profile $profile"
    onboard_aws_write iam create-instance-profile --instance-profile-name "$profile"
  fi
  onboard_aws_write iam add-role-to-instance-profile \
    --instance-profile-name "$profile" \
    --role-name "$role" 2>/dev/null || true

  local profile_arn assoc_id assoc_profile state i
  profile_arn="$(onboard_aws_read iam get-instance-profile \
    --instance-profile-name "$profile" \
    --query 'InstanceProfile.Arn' --output text)"

  assoc_id="$(onboard_aws_read ec2 describe-iam-instance-profile-associations \
    --filters "Name=instance-id,Values=${instance_id}" \
    --query 'IamInstanceProfileAssociations[0].AssociationId' --output text 2>/dev/null || true)"
  assoc_profile="$(onboard_aws_read ec2 describe-iam-instance-profile-associations \
    --filters "Name=instance-id,Values=${instance_id}" \
    --query 'IamInstanceProfileAssociations[0].IamInstanceProfile.Arn' --output text 2>/dev/null || true)"

  if [[ "$assoc_profile" == "$profile_arn" ]]; then
    onboard_log "instance profile already associated"
  else
    if [[ -n "$assoc_id" && "$assoc_id" != "None" ]]; then
      onboard_log "replacing existing instance profile on $instance_id"
      onboard_aws_write ec2 disassociate-iam-instance-profile --association-id "$assoc_id"
    fi
    onboard_log "associating $profile with $instance_id"
    onboard_aws_write ec2 associate-iam-instance-profile \
      --instance-id "$instance_id" \
      --iam-instance-profile "Arn=${profile_arn}"
    state=""
    for i in $(seq 1 12); do
      state="$(onboard_aws_read ec2 describe-iam-instance-profile-associations \
        --filters "Name=instance-id,Values=${instance_id}" \
        --query 'IamInstanceProfileAssociations[0].State' --output text 2>/dev/null || true)"
      [[ "$state" == "associated" ]] && break
      sleep 5
    done
    if [[ "$state" != "associated" ]]; then
      onboard_log "ERROR: IAM instance profile not associated (state=${state:-unknown})"
      onboard_log "S3 backups will fail until EC2 has role $profile attached."
      rm -rf "$workdir"
      exit 1
    fi
  fi

  rm -rf "$workdir"
  onboard_log "IAM ready: role=$role policy=$policy_name"
}

onboard_verify_iam_metadata() {
  local role
  role="$(onboard_ssh_read "bash -s" <<'REMOTE'
set -euo pipefail
meta="http://169.254.169.254/latest/meta-data/iam/security-credentials/"
token=""
if token=$(curl -sf --connect-timeout 2 -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); then
  curl -sf --connect-timeout 2 -H "X-aws-ec2-metadata-token: ${token}" "$meta" || true
else
  curl -sf --connect-timeout 2 "$meta" || true
fi
REMOTE
)"
  if [[ -z "$role" || "$role" == *"404"* ]]; then
    onboard_log "ERROR: EC2 instance metadata has no IAM role (404 or empty)."
    onboard_log "Attach instance profile before S3 smoke — see REBUILD_INSTANCE_RUNBOOK.md Phase 4."
    exit 1
  fi
  onboard_log "IAM metadata role: $role"
}

onboard_configure_node() {
  local bucket=$1 ksuid=$2
  local region="${ONBOARD_AWS_REGION:-us-east-1}"
  onboard_verify_iam_metadata
  onboard_ssh_write "sudo bash -s" <<REMOTE
set -e
ENV=/opt/pbx3api/.env
touch "\$ENV"
grep -q '^PBX3_ORG_BUCKET=' "\$ENV" 2>/dev/null && \
  sed -i 's/^PBX3_ORG_BUCKET=.*/PBX3_ORG_BUCKET=${bucket}/' "\$ENV" || \
  echo 'PBX3_ORG_BUCKET=${bucket}' >> "\$ENV"
grep -q '^PBX3_DIRECTORY_BACKUP_UPLOAD=' "\$ENV" 2>/dev/null && \
  sed -i 's/^PBX3_DIRECTORY_BACKUP_UPLOAD=.*/PBX3_DIRECTORY_BACKUP_UPLOAD=true/' "\$ENV" || \
  echo 'PBX3_DIRECTORY_BACKUP_UPLOAD=true' >> "\$ENV"
grep -q '^PBX3_FLEET_MODE=' "\$ENV" 2>/dev/null && \
  sed -i 's/^PBX3_FLEET_MODE=.*/PBX3_FLEET_MODE=true/' "\$ENV" || \
  echo 'PBX3_FLEET_MODE=true' >> "\$ENV"
grep -q '^PBX3_SBC_EGRESS_HOST=' "\$ENV" 2>/dev/null && \
  sed -i 's/^PBX3_SBC_EGRESS_HOST=.*/PBX3_SBC_EGRESS_HOST=${PBX3_SBC_EGRESS_HOST:-sbc.pbx3.com}/' "\$ENV" || \
  echo 'PBX3_SBC_EGRESS_HOST=${PBX3_SBC_EGRESS_HOST:-sbc.pbx3.com}' >> "\$ENV"
grep -q '^AWS_DEFAULT_REGION=' "\$ENV" 2>/dev/null && \
  sed -i 's/^AWS_DEFAULT_REGION=.*/AWS_DEFAULT_REGION=${region}/' "\$ENV" || \
  echo 'AWS_DEFAULT_REGION=${region}' >> "\$ENV"
sed -i '/^AWS_ACCESS_KEY_ID=\$/d;/^AWS_SECRET_ACCESS_KEY=\$/d' "\$ENV"
sed -i '/^AWS_ACCESS_KEY_ID=$/d;/^AWS_SECRET_ACCESS_KEY=$/d' "\$ENV"
sed -i 's/^# PBX3_ORG_BUCKET=.*/PBX3_ORG_BUCKET=${bucket}/' "\$ENV" 2>/dev/null || true
sed -i 's/^# PBX3_DIRECTORY_BACKUP_UPLOAD=true/PBX3_DIRECTORY_BACKUP_UPLOAD=true/' "\$ENV" 2>/dev/null || true
cd /opt/pbx3api
sudo git config --global --add safe.directory /opt/pbx3api 2>/dev/null || true
if [[ "${ONBOARD_GIT_PULL:-0}" == "1" ]]; then
  sudo git fetch origin directory && sudo git pull origin directory
fi
sudo php artisan config:clear
# Instance SIP pcap off in fleet (SBC is the edge). See FLEET_LOG_RETENTION_REQUIREMENTS.md R3.
if [[ -x /opt/pbx3/scripts/siplog-set-mode.sh ]]; then
  /opt/pbx3/scripts/siplog-set-mode.sh fleet || true
else
  touch /opt/pbx3/service/sys-ua-siplog/down 2>/dev/null || true
  sv d sys-ua-siplog 2>/dev/null || true
fi
# Daily log ship cron (no-op without PBX3_ORG_BUCKET). Same as pbx3api installer.
if [[ ! -f /etc/cron.d/pbx3-logs ]]; then
  if [[ -f /opt/pbx3api/scripts/cron.d/pbx3-logs.example ]]; then
    sudo install -m 644 -o root -g root /opt/pbx3api/scripts/cron.d/pbx3-logs.example /etc/cron.d/pbx3-logs
    echo 'installed /etc/cron.d/pbx3-logs'
  fi
fi
sudo -u www-data env HOME=/tmp php artisan tinker --execute="
use Illuminate\\\\Support\\\\Facades\\\\Storage;
\\\$disk = Storage::disk('pbx3_org');
\\\$prefix = 'instances/${ksuid}/backups';
\\\$dirs = \\\$disk->directories(\\\$prefix);
if (\\\$dirs === []) {
  echo 's3_list_ok_empty' . PHP_EOL;
} else {
  echo 's3_list_ok_' . count(\\\$dirs) . PHP_EOL;
}
\\\$key = 'instances/${ksuid}/_onboard_smoke.txt';
\\\$disk->put(\\\$key, 'onboard ' . gmdate('c'));
\\\$disk->delete(\\\$key);
echo 's3_smoke_ok' . PHP_EOL;
"
REMOTE
  if [[ "$ONBOARD_DRY_RUN" != "1" ]]; then
    onboard_log "node configured and S3 smoke passed"
  fi
}

onboard_verify_catalog() {
  local ksuid=$1 bucket=$2
  local count
  if [[ "$ONBOARD_DRY_RUN" == "1" ]]; then
    onboard_log "DRY-RUN: verify catalog contains $ksuid"
    return 0
  fi
  count="$(onboard_aws_read s3 cp "s3://${bucket}/catalog/instance-index.json" - \
    | jq --arg id "$ksuid" '[.instances[] | select(.id == $id)] | length')"
  [[ "$count" -ge 1 ]] || { onboard_log "catalog missing instance $ksuid"; exit 1; }
  onboard_log "catalog verified for $ksuid"
}

# Fleet nodes require trunks.pkey=Egress for dial-plane (see FLEET_TRUNK_PEERING_DECISION.md).
# Seed DB row + genAst + Asterisk restart. SBC domain/dispatcher cutover remains a separate edge step.
onboard_seed_egress_trunk() {
  local seed_local sbc_host sbc_failover fail_env=""
  sbc_host="${PBX3_SBC_EGRESS_HOST:-sbc.pbx3.com}"
  sbc_failover="${PBX3_SBC_EGRESS_FAILOVER_HOST:-}"
  # This file lives in tools/lib/; seed script is tools/seed-fleet-egress-trunk.sh
  seed_local="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/seed-fleet-egress-trunk.sh"
  [[ -f "$seed_local" ]] || {
    onboard_log "seed script not found: $seed_local"
    exit 1
  }

  if [[ "$ONBOARD_DRY_RUN" == "1" ]]; then
    onboard_log "DRY-RUN: would seed Egress → ${sbc_host} (failover=${sbc_failover:-none}) + genAst + asterisk restart"
    return 0
  fi

  onboard_log "step: fleet Egress trunk (seed + genAst)"
  onboard_ssh_opts
  scp "${ONBOARD_SSH_OPTS[@]}" "$seed_local" "${ONBOARD_SSH_TARGET}:/tmp/seed-fleet-egress-trunk.sh"

  if [[ -n "$sbc_failover" ]]; then
    fail_env="PBX3_SBC_EGRESS_FAILOVER_HOST=${sbc_failover}"
  fi

  # shellcheck disable=SC2086
  onboard_ssh_write "bash -s" <<REMOTE
set -e
chmod +x /tmp/seed-fleet-egress-trunk.sh
sudo env PBX3_SBC_EGRESS_HOST='${sbc_host}' ${fail_env} \\
  /tmp/seed-fleet-egress-trunk.sh /opt/pbx3/db/sqlite.db
rm -f /tmp/seed-fleet-egress-trunk.sh
# Publish PJSIP Egress into ASTLOCALCONF, link into /etc/asterisk, then full Asterisk restart
# (pjsip reload alone is not enough after egress seed — OPS_ASTERISK_AFTER_EGRESS_GENAST.md).
sudo /opt/pbx3/scripts/genAst.sh
sudo php /opt/pbx3/php/utilities/runLinker.php >/dev/null
sudo systemctl restart asterisk
echo "egress_seed_ok host=${sbc_host}"
REMOTE
  onboard_log "Egress trunk seeded (host=${sbc_host}); Asterisk restarted"
}
