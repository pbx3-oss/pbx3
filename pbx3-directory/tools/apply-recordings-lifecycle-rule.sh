#!/usr/bin/env bash
# Apply S3 lifecycle on the dedicated recordings bucket (Phase S7).
# Expire objects tagged class=recording after N days (aligns with tenant recmaxage).
#
# Usage:
#   ./apply-recordings-lifecycle-rule.sh RECORDINGS_BUCKET [DAYS]
#   ./apply-recordings-lifecycle-rule.sh RECORDINGS_BUCKET TENANT_SHORTUID
# Examples:
#   ./apply-recordings-lifecycle-rule.sh 08jzwn-pbx3-recordings 60
#   ./apply-recordings-lifecycle-rule.sh 08jzwn-pbx3-recordings dhbm8x
#     (reads maxage_days from s3://BUCKET/tenants/SHORTUID/recordings/policy.json, fallback 60)
#
# Requires: aws CLI with s3:PutLifecycleConfiguration on the recordings bucket.
# Run from Mac / ops — NOT from a PBX node role.
# Uploads must tag media with class=recording (pbx3api RecordingS3UploadService).
#
# NOTE: put-bucket-lifecycle-configuration replaces the whole config on this bucket.
# The recordings bucket should only hold recording objects — do not mix catalog/backups here.

set -euo pipefail

BUCKET="${1:?usage: $0 RECORDINGS_BUCKET [DAYS|TENANT_SHORTUID]}"
ARG2="${2:-60}"

if [[ "$ARG2" =~ ^[0-9]+$ ]]; then
  DAYS="$ARG2"
else
  TENANT="$ARG2"
  POLICY_KEY="tenants/${TENANT}/recordings/policy.json"
  echo "Reading maxage_days from s3://${BUCKET}/${POLICY_KEY} ..."
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq required when second argument is a tenant shortuid" >&2
    exit 1
  fi
  DAYS="$(aws s3 cp "s3://${BUCKET}/${POLICY_KEY}" - 2>/dev/null | jq -r '.maxage_days // 60' || echo 60)"
  if [[ ! "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
    echo "WARN: invalid maxage_days from policy; using 60" >&2
    DAYS=60
  fi
  echo "Using maxage_days=${DAYS} from policy.json"
fi

RULE_ID="pbx3-expire-tagged-recordings-${DAYS}d"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi

ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
if [[ "$ARN" == *":assumed-role/pbx3-node-"* ]]; then
  echo "ERROR: AWS identity is a PBX EC2 node role ($ARN)." >&2
  echo "Run on Mac/ops with admin credentials — see OPS_S3_RUNBOOK.md §13." >&2
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
          "Prefix": "tenants/",
          "Tags": [
            { "Key": "class", "Value": "recording" }
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

echo "Applying lifecycle to s3://${BUCKET} (tag class=recording, expire after ${DAYS} days)..."
echo "NOTE: private encrypted DR — not PCI-attested."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration "file://${TMP}"

echo "Done. Verify: aws s3api get-bucket-lifecycle-configuration --bucket ${BUCKET}"
