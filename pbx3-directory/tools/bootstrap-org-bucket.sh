#!/usr/bin/env bash
# Seed a fleet org bucket (catalog + CORS). Library for the control installer (D1).
#
# Lab (Garage on this box): installer starts Garage, then calls this.
# Cloud (T2 later): same script against AWS/R2 with AWS_ENDPOINT unset.
#
# Does not print access keys. Writes nothing to stdout except a small JSON
# summary when --json is passed (catalog URL, bucket). Secrets stay in env.
#
# Usage (on the control host, after S3-compatible endpoint is up):
#   AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… \
#   AWS_ENDPOINT=http://127.0.0.1:3900 AWS_DEFAULT_REGION=garage \
#   ./bootstrap-org-bucket.sh --slug lab [--catalog-url URL]
#
# See FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md Appendix B.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/control-common.sh
source "$SCRIPT_DIR/lib/control-common.sh"

SLUG="${PBX3_FLEET_SLUG:-}"
CATALOG_URL="${PBX3_CATALOG_URL:-}"
JSON_OUT=0
FORCE=0

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)
      SLUG="${2:?}"
      shift 2
      ;;
    --catalog-url)
      CATALOG_URL="${2:?}"
      shift 2
      ;;
    --json) JSON_OUT=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *)
      control_err "unknown arg: $1"
      usage 1
      ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  control_err "set --slug or PBX3_FLEET_SLUG"
  exit 1
fi

BUCKET="$(control_org_bucket_from_slug "$SLUG")"
ORG_ID="$SLUG"
ENDPOINT="${AWS_ENDPOINT:-}"
REGION="${AWS_DEFAULT_REGION:-garage}"
CATALOG_KEY="catalog/instance-index.json"

control_require_cmd aws jq openssl

aws_s3() {
  local -a cmd=(aws)
  if [[ -n "$ENDPOINT" ]]; then
    cmd+=(--endpoint-url "$ENDPOINT")
  fi
  cmd+=("$@")
  "${cmd[@]}"
}

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  control_err "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set (installer writes them; do not paste in Lab docs)"
  exit 1
fi

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$REGION"
# Path-style is required for Garage / most S3-compatible labs (Rule 9).
export AWS_EC2_METADATA_DISABLED=true

if ! aws_s3 s3 ls "s3://${BUCKET}" >/dev/null 2>&1; then
  control_log "Creating bucket s3://${BUCKET}"
  if [[ -n "$ENDPOINT" ]]; then
    aws_s3 s3 mb "s3://${BUCKET}" >/dev/null
  else
    if [[ "$REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
    else
      aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
        --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
    fi
  fi
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

EXISTING=0
if aws_s3 s3 ls "s3://${BUCKET}/${CATALOG_KEY}" >/dev/null 2>&1; then
  EXISTING=1
fi

if [[ "$EXISTING" -eq 1 && "$FORCE" -ne 1 ]]; then
  control_log "Keeping existing ${CATALOG_KEY}"
else
  control_empty_catalog_json "$ORG_ID" >"${TMP}/instance-index.json"
  aws_s3 s3 cp "${TMP}/instance-index.json" "s3://${BUCKET}/${CATALOG_KEY}" \
    --content-type application/json >/dev/null
  control_log "Seeded ${CATALOG_KEY}"
fi

# CORS: SPA localhost Vite + optional catalog URL origin. Fail-soft on Garage gaps.
CORS_FILE="${TMP}/cors.json"
ORIGINS='["http://localhost:5173","http://127.0.0.1:5173"]'
if [[ -n "$CATALOG_URL" ]]; then
  origin="$(printf '%s' "$CATALOG_URL" | sed -E 's#(https?://[^/]+).*#\1#')"
  ORIGINS="$(jq -cn --arg o "$origin" --argjson base "$ORIGINS" '$base + [$o] | unique')"
fi
jq -n --argjson origins "$ORIGINS" '{
  CORSRules: [{
    AllowedOrigins: $origins,
    AllowedMethods: ["GET","HEAD"],
    AllowedHeaders: ["*"],
    ExposeHeaders: ["ETag"],
    MaxAgeSeconds: 3600
  }]
}' >"$CORS_FILE"

if aws_s3 s3api put-bucket-cors --bucket "$BUCKET" --cors-configuration "file://${CORS_FILE}" >/dev/null 2>&1; then
  control_log "Wrote bucket CORS"
else
  control_log "CORS API not available on this endpoint (nginx catalog proxy still adds headers)"
fi

if [[ -z "$CATALOG_URL" && -n "$ENDPOINT" ]]; then
  CATALOG_URL="${ENDPOINT%/}/${BUCKET}/${CATALOG_KEY}"
elif [[ -z "$CATALOG_URL" ]]; then
  CATALOG_URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/${CATALOG_KEY}"
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  jq -n --arg bucket "$BUCKET" --arg catalog_url "$CATALOG_URL" --arg region "$REGION" \
    '{bucket:$bucket, catalog_url:$catalog_url, region:$region}'
else
  control_log "bucket=${BUCKET}"
  control_log "catalog_url=${CATALOG_URL}"
fi
