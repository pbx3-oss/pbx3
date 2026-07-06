#!/usr/bin/env bash
# Download the newest instance backup from the org S3 bucket (S8 rebuild runbook).
#
# Run from Mac/ops with IAM that can read instances/{ksuid}/backups/* (not the node role).
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./fetch-latest-instance-backup.sh \
#     --instance-id 3DmAsxePTWQZgynBYXE8obIRqEE \
#     --output-dir ~/Downloads
#
# Writes: {output-dir}/pbx3bak.{epoch}.zip (name required by restore-backup-zip.sh)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

INSTANCE_ID=""
OUTPUT_DIR="."
STAMP=""

usage() {
  cat <<'EOF'
Usage: fetch-latest-instance-backup.sh --instance-id KSUID [--output-dir DIR] [--stamp YYYYMMDDTHHMMSSZ]

  --instance-id KSUID   globals.id for the instance (S3 prefix)
  --output-dir DIR      where to write pbx3bak.{epoch}.zip (default: .)
  --stamp STAMP         use this archive instead of newest (optional)

Requires: PBX3_ORG_BUCKET, aws, jq
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance-id) INSTANCE_ID=$2; shift 2 ;;
    --output-dir) OUTPUT_DIR=$2; shift 2 ;;
    --stamp) STAMP=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "fetch-latest-instance-backup: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$INSTANCE_ID" ]] || { echo "fetch-latest-instance-backup: --instance-id required" >&2; exit 1; }

registrar_require_cmd
BUCKET="$(registrar_bucket)"
mkdir -p "$OUTPUT_DIR"

aws_fetch() {
  local -a cmd=(aws)
  [[ -n "${AWS_PROFILE:-}" ]] && cmd+=(--profile "$AWS_PROFILE")
  [[ -n "${AWS_DEFAULT_REGION:-}" ]] && cmd+=(--region "$AWS_DEFAULT_REGION")
  cmd+=("$@")
  "${cmd[@]}"
}

stamp_to_epoch() {
  local stamp=$1
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$stamp" <<'PY'
import sys
from datetime import datetime, timezone
s = sys.argv[1]
dt = datetime.strptime(s, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
PY
    return
  fi
  local y mo d h mi se
  y=${stamp:0:4}; mo=${stamp:4:2}; d=${stamp:6:2}
  h=${stamp:9:2}; mi=${stamp:11:2}; se=${stamp:13:2}
  if date -u -d "${y}-${mo}-${d} ${h}:${mi}:${se}" +%s 2>/dev/null; then
    return
  fi
  date -u -j -f "%Y-%m-%d %H:%M:%S" "${y}-${mo}-${d} ${h}:${mi}:${se}" +%s
}

resolve_latest_stamp() {
  local prefixes
  prefixes="$(aws_fetch s3 ls "s3://${BUCKET}/instances/${INSTANCE_ID}/backups/" \
    | awk '/ PRE / { gsub(/\//, "", $2); print $2 }' | sort || true)"
  if [[ -z "$prefixes" ]]; then
    echo "fetch-latest-instance-backup: no backups under instances/${INSTANCE_ID}/backups/" >&2
    exit 1
  fi
  echo "$prefixes" | tail -1
}

if [[ -z "$STAMP" ]]; then
  STAMP="$(resolve_latest_stamp)"
fi

if [[ ! "$STAMP" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "fetch-latest-instance-backup: invalid stamp: $STAMP" >&2
  exit 1
fi

EPOCH="$(stamp_to_epoch "$STAMP")"
OUTFILE="${OUTPUT_DIR}/pbx3bak.${EPOCH}.zip"
S3_KEY="instances/${INSTANCE_ID}/backups/${STAMP}/backup.zip"

echo "fetch-latest-instance-backup: s3://${BUCKET}/${S3_KEY} -> ${OUTFILE}" >&2
aws_fetch s3 cp "s3://${BUCKET}/${S3_KEY}" "$OUTFILE" --only-show-errors >&2

if [[ ! -s "$OUTFILE" ]]; then
  echo "fetch-latest-instance-backup: download failed or empty file" >&2
  exit 1
fi

echo "$OUTFILE"
echo "fetch-latest-instance-backup: stamp=${STAMP} epoch=${EPOCH}" >&2
