#!/usr/bin/env bash
# Apply S3 lifecycle: expire objects tagged class=backup after N days (option C S3 leg).
# Does not delete objects when a node prunes local zips — only age-based expiry.
#
# Usage:
#   ./apply-backup-lifecycle-rule.sh BUCKET_NAME [DAYS]
#   ./apply-backup-lifecycle-rule.sh BUCKET_NAME INSTANCE_KSUID
# Examples:
#   ./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 30
#   ./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE
#     (reads maxage_days from s3://BUCKET/instances/KSUID/backups/policy.json, fallback 30)
#
# Requires: aws CLI with s3:PutLifecycleConfiguration on the bucket.
# Run from your laptop / ops workstation (IAM admin or bucket owner) — NOT from a PBX
# EC2 node: instance roles (e.g. pbx3-node-08jzwn) must not get lifecycle permissions.
# Uploads must tag backup.zip and manifest.json with class=backup (pbx3api 119b1f7+).

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

RULE_ID="pbx3-expire-tagged-backups-${DAYS}d"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi

ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
if [[ "$ARN" == *":assumed-role/pbx3-node-"* ]]; then
  echo "ERROR: AWS identity is a PBX EC2 node role ($ARN)." >&2
  echo "Run this script on your Mac (or ops workstation) with admin credentials," >&2
  echo "not on the PBX server. See pbx3-directory/docs/OPS_S3_RUNBOOK.md § S3 lifecycle." >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<EOF
{
  "Rules": [
    {
      "ID": "${RULE_ID}",
      "Status": "Enabled",
      "Filter": {
        "And": {
          "Prefix": "instances/",
          "Tags": [
            { "Key": "class", "Value": "backup" }
          ]
        }
      },
      "Expiration": {
        "Days": ${DAYS}
      }
    }
  ]
}
EOF

echo "Applying lifecycle to s3://${BUCKET} (tag class=backup, expire after ${DAYS} days)..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration "file://${TMP}"

echo "Done. Verify: aws s3api get-bucket-lifecycle-configuration --bucket ${BUCKET}"
