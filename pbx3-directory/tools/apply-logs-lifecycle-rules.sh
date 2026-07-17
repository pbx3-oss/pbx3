#!/usr/bin/env bash
# Merge S3 lifecycle rules for instance log ship (Phase 1).
# Tags: class=syslog / class=asterisk-messages (30d), class=cdr (60d) under instances/.
#
# Usage:
#   ./apply-logs-lifecycle-rules.sh BUCKET_NAME [SYSLOG_DAYS] [CDR_DAYS]
#   ./apply-logs-lifecycle-rules.sh 08jzwn-pbx3
#   ./apply-logs-lifecycle-rules.sh 08jzwn-pbx3 30 60
#
# Merges with existing bucket lifecycle (does not wipe backup/recording rules on this bucket).
# Run from ops laptop — NOT from a PBX node role.
# Spec: FLEET_LOG_RETENTION_REQUIREMENTS.md · OPS_S3_RUNBOOK.md § logs

set -euo pipefail

BUCKET="${1:?bucket name required}"
SYSLOG_DAYS="${2:-30}"
CDR_DAYS="${3:-60}"
MSG_DAYS="$SYSLOG_DAYS"

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
  echo "Run on your Mac / ops workstation. See OPS_S3_RUNBOOK.md." >&2
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

# Drop prior pbx3 log expire rules, keep everything else
jq --argjson syslog_days "$SYSLOG_DAYS" --argjson msg_days "$MSG_DAYS" --argjson cdr_days "$CDR_DAYS" '
  .Rules //= []
  | .Rules |= map(select(.ID | tostring | test("^pbx3-expire-log-") | not))
  | .Rules += [
      {
        "ID": ("pbx3-expire-log-syslog-" + ($syslog_days|tostring) + "d"),
        "Status": "Enabled",
        "Filter": {
          "And": {
            "Prefix": "instances/",
            "Tags": [{ "Key": "class", "Value": "syslog" }]
          }
        },
        "Expiration": { "Days": $syslog_days }
      },
      {
        "ID": ("pbx3-expire-log-asterisk-messages-" + ($msg_days|tostring) + "d"),
        "Status": "Enabled",
        "Filter": {
          "And": {
            "Prefix": "instances/",
            "Tags": [{ "Key": "class", "Value": "asterisk-messages" }]
          }
        },
        "Expiration": { "Days": $msg_days }
      },
      {
        "ID": ("pbx3-expire-log-cdr-" + ($cdr_days|tostring) + "d"),
        "Status": "Enabled",
        "Filter": {
          "And": {
            "Prefix": "instances/",
            "Tags": [{ "Key": "class", "Value": "cdr" }]
          }
        },
        "Expiration": { "Days": $cdr_days }
      }
    ]
' "$TMP_EXISTING" >"$TMP_OUT"

echo "Applying merged lifecycle to s3://${BUCKET} (syslog/messages ${SYSLOG_DAYS}d, cdr ${CDR_DAYS}d)..."
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration "file://${TMP_OUT}"

echo "Done. Verify: aws s3api get-bucket-lifecycle-configuration --bucket ${BUCKET}"
