#!/usr/bin/env bash
# Tag existing backup objects with class=backup (lifecycle filter).
# Run after adding s3:PutObjectTagging to the node policy, or from Mac with bucket admin.
#
# Usage:
#   ./tag-s3-backups.sh BUCKET INSTANCE_KSUID
# Example:
#   ./tag-s3-backups.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE

set -euo pipefail

BUCKET="${1:?bucket name required}"
KSUID="${2:?instance KSUID required}"
PREFIX="instances/${KSUID}/backups/"
TAGGING="TagSet=[{Key=class,Value=backup}]"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi

echo "Tagging backup.zip and manifest.json under s3://${BUCKET}/${PREFIX} ..."
count=0
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  case "$key" in
    */backup.zip|*/manifest.json)
      echo "  $key"
      aws s3api put-object-tagging --bucket "$BUCKET" --key "$key" --tagging "$TAGGING"
      count=$((count + 1))
      ;;
  esac
done < <(aws s3api list-objects-v2 --bucket "$BUCKET" --prefix "$PREFIX" --query 'Contents[].Key' --output text | tr '\t' '\n')

echo "Tagged ${count} object(s)."
