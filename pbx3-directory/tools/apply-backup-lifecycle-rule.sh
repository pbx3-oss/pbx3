#!/usr/bin/env bash
# Apply S3 lifecycle: expire objects tagged class=backup after N days (option C S3 leg).
# Does not delete objects when a node prunes local zips — only age-based expiry.
#
# Usage:
#   ./apply-backup-lifecycle-rule.sh BUCKET_NAME [DAYS]
# Example:
#   ./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 30
#
# Requires: aws CLI with s3:PutLifecycleConfiguration on the bucket.
# Run from your laptop / ops workstation (IAM admin or bucket owner) — NOT from a PBX
# EC2 node: instance roles (e.g. pbx3-node-08jzwn) must not get lifecycle permissions.
# Uploads must tag backup.zip and manifest.json with class=backup (pbx3api 119b1f7+).

set -euo pipefail

BUCKET="${1:?bucket name required}"
DAYS="${2:-30}"
RULE_ID="pbx3-expire-tagged-backups-${DAYS}d"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
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
