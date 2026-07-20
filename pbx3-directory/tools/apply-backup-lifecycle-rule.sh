#!/usr/bin/env bash
# Apply / merge S3 lifecycle: expire objects tagged class=backup after N days (option C S3 leg).
# Covers instance backups (prefix instances/) and SBC backups (prefix sbc/).
# Does not delete objects when a node prunes local zips — only age-based expiry.
# Merges with existing bucket lifecycle (keeps log/recording rules).
#
# Usage:
#   ./apply-backup-lifecycle-rule.sh BUCKET_NAME [DAYS]
#   ./apply-backup-lifecycle-rule.sh BUCKET_NAME INSTANCE_KSUID
# Examples:
#   ./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 30
#   ./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE
#     (reads maxage_days from s3://BUCKET/instances/KSUID/backups/policy.json, fallback 30)
#
# Requires: aws CLI + jq with s3:PutLifecycleConfiguration on the bucket.
# Run from your laptop / ops workstation (IAM admin or bucket owner) — NOT from a PBX
# EC2 node: instance roles (e.g. pbx3-node-08jzwn) must not get lifecycle permissions.
# Uploads must tag backup.zip and manifest.json with class=backup
# (pbx3api for instances; pbx3sbc scripts/upload-sbc-backup.sh for SBC).
#
# Spec: DESIGN_RULES.md § backup retention · SBC_BACKUP_RESTORE_REQUIREMENTS.md

set -euo pipefail

BUCKET="${1:?bucket name required}"
ARG2="${2:-30}"

if [[ "$ARG2" =~ ^[0-9]+$ ]]; then
  DAYS="$ARG2"
else
  KSUID="$ARG2"
  POLICY_KEY="instances/${KSUID}/backups/policy.json"
  echo "Reading maxage_days from s3://${BUCKET}/${POLICY_KEY} ..."
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq required when second argument is INSTANCE_KSUID" >&2
    exit 1
  fi
  DAYS="$(aws s3 cp "s3://${BUCKET}/${POLICY_KEY}" - 2>/dev/null | jq -r '.maxage_days // 30' || echo 30)"
  if [[ ! "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
    echo "WARN: invalid maxage_days from policy; using 30" >&2
    DAYS=30
  fi
  echo "Using maxage_days=${DAYS} from policy.json"
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
if [[ "$ARN" == *":assumed-role/pbx3-node-"* ]]; then
  echo "ERROR: AWS identity is a PBX EC2 node role ($ARN)." >&2
  echo "Run this script on your Mac (or ops workstation) with admin credentials," >&2
  echo "not on the PBX server. See pbx3-directory/docs/OPS_S3_RUNBOOK.md § S3 lifecycle." >&2
  exit 1
fi

TMP_EXISTING="$(mktemp)"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_EXISTING" "$TMP_OUT"' EXIT

if aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" >"$TMP_EXISTING" 2>/dev/null; then
  :
else
  echo '{"Rules":[]}' >"$TMP_EXISTING"
fi

# Drop prior pbx3 backup expire rules (legacy single-rule id + new prefixed ids), keep everything else.
jq --argjson days "$DAYS" '
  {Rules: (.Rules // [])}
  | .Rules |= map(select(
      (.ID | tostring | test("^pbx3-expire-tagged-backups") | not)
      and (.ID | tostring | test("^pbx3-expire-backup-") | not)
    ))
  | .Rules += [
      {
        "ID": ("pbx3-expire-backup-instances-" + ($days|tostring) + "d"),
        "Status": "Enabled",
        "Filter": {
          "And": {
            "Prefix": "instances/",
            "Tags": [{ "Key": "class", "Value": "backup" }]
          }
        },
        "Expiration": { "Days": $days }
      },
      {
        "ID": ("pbx3-expire-backup-sbc-" + ($days|tostring) + "d"),
        "Status": "Enabled",
        "Filter": {
          "And": {
            "Prefix": "sbc/",
            "Tags": [{ "Key": "class", "Value": "backup" }]
          }
        },
        "Expiration": { "Days": $days }
      }
    ]
' "$TMP_EXISTING" >"$TMP_OUT"

echo "Applying merged lifecycle to s3://${BUCKET} (instances/ + sbc/ tag class=backup, expire after ${DAYS} days)..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration "file://${TMP_OUT}"

echo "Done. Verify: aws s3api get-bucket-lifecycle-configuration --bucket ${BUCKET}"
echo "One-time ops (lab): re-run this after enabling SBC backup uploads so sbc/ archives age out."
