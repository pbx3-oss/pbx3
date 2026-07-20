#!/usr/bin/env bash
# Download the newest (or chosen) SBC backup from the org S3 bucket.
# Spec: pbx3/pbx3-directory/docs/SBC_BACKUP_RESTORE_REQUIREMENTS.md
#
# Run from Mac/ops (or scratch host with read IAM) — not required to be the live SBC.
#
# Usage:
#   export PBX3_ORG_BUCKET=08jzwn-pbx3
#   ./fetch-latest-sbc-backup.sh --sbc-id sbc --output-dir ~/Downloads
#   ./fetch-latest-sbc-backup.sh --sbc-id sbc --stamp 20260720T172044Z --output-dir .
#
# Writes: {output-dir}/sbcbak.{epoch}.zip (name required by restore-sbc-backup.sh)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/registrar-common.sh
source "$SCRIPT_DIR/lib/registrar-common.sh"

SBC_ID=""
OUTPUT_DIR="."
STAMP=""

usage() {
  cat <<'EOF'
Usage: fetch-latest-sbc-backup.sh --sbc-id ID [--output-dir DIR] [--stamp YYYYMMDDTHHMMSSZ]

  --sbc-id ID         PBX3_SBC_ID (S3 prefix under sbc/)
  --output-dir DIR    where to write sbcbak.{epoch}.zip (default: .)
  --stamp STAMP       use this archive instead of newest (optional)

Requires: PBX3_ORG_BUCKET, aws, jq (jq optional)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbc-id) SBC_ID=$2; shift 2 ;;
    --output-dir) OUTPUT_DIR=$2; shift 2 ;;
    --stamp) STAMP=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "fetch-latest-sbc-backup: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$SBC_ID" ]] || { echo "fetch-latest-sbc-backup: --sbc-id required" >&2; exit 1; }

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
  prefixes="$(aws_fetch s3 ls "s3://${BUCKET}/sbc/${SBC_ID}/backups/" \
    | awk '/ PRE / { gsub(/\//, "", $2); print $2 }' | sort || true)"
  if [[ -z "$prefixes" ]]; then
    echo "fetch-latest-sbc-backup: no backups under sbc/${SBC_ID}/backups/" >&2
    exit 1
  fi
  echo "$prefixes" | tail -1
}

if [[ -z "$STAMP" ]]; then
  STAMP="$(resolve_latest_stamp)"
fi

if [[ ! "$STAMP" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "fetch-latest-sbc-backup: invalid stamp: $STAMP" >&2
  exit 1
fi

EPOCH="$(stamp_to_epoch "$STAMP")"
OUTFILE="${OUTPUT_DIR}/sbcbak.${EPOCH}.zip"
S3_KEY="sbc/${SBC_ID}/backups/${STAMP}/backup.zip"

echo "fetch-latest-sbc-backup: s3://${BUCKET}/${S3_KEY} -> ${OUTFILE}" >&2
aws_fetch s3 cp "s3://${BUCKET}/${S3_KEY}" "$OUTFILE" --only-show-errors >&2

if [[ ! -s "$OUTFILE" ]]; then
  echo "fetch-latest-sbc-backup: download failed or empty file" >&2
  exit 1
fi

echo "$OUTFILE"
echo "fetch-latest-sbc-backup: stamp=${STAMP} epoch=${EPOCH}" >&2
