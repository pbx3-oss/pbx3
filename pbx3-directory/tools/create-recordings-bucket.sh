#!/usr/bin/env bash
# Create a dedicated PBX3 recordings bucket (Phase S7 — PCI-shaped baseline).
#
# Usage:
#   ./create-recordings-bucket.sh ORG_BUCKET [REGION]
# Examples:
#   ./create-recordings-bucket.sh 08jzwn-pbx3 us-east-1
#   ./create-recordings-bucket.sh acme-pbx3 eu-west-1
#
# Naming: recordings bucket is "{ORG_BUCKET}-recordings" (fleet-scoped, NOT per instance).
# See RECORDINGS_STORAGE_DESIGN.md §6.3 and OPS_S3_RUNBOOK.md § Recordings bucket.
#
# What this script does:
#   1. Create private bucket (Block Public Access all ON)
#   2. Default encryption SSE-S3 (AES256)
#   3. BucketOwnerEnforced (ACLs disabled)
#   4. Bucket policy DenyInsecureTransport (TLS only)
#   5. Optionally attach gatekeeper IAM (if CONTROL_ROLE set)
#
# Does NOT: versioning, KMS CMK, CloudTrail, object Lock — those are S7+.
# This is private encrypted DR storage — NOT PCI-attested.
#
# Requires: aws CLI with s3:CreateBucket + PutBucket* + PutBucketPolicy.
# Run from ops laptop / root / IAM admin — NOT from a PBX node role.

set -euo pipefail

ORG_BUCKET="${1:?usage: $0 ORG_BUCKET [REGION]}"
REGION="${2:-us-east-1}"
REC_BUCKET="${ORG_BUCKET}-recordings"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$(cd "$SCRIPT_DIR/../schema" && pwd)"
POLICY_TMPL="$SCHEMA_DIR/pbx3-recordings-bucket-policy.json.tmpl"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi

ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
if [[ "$ARN" == *":assumed-role/pbx3-node-"* ]]; then
  echo "ERROR: AWS identity is a PBX EC2 node role ($ARN)." >&2
  echo "Run on Mac/ops with admin credentials — see OPS_S3_RUNBOOK.md." >&2
  exit 1
fi

echo "Caller: $ARN"
echo "Creating recordings bucket: s3://${REC_BUCKET} (region=${REGION})"
echo "  paired with org/fleet bucket: s3://${ORG_BUCKET}"
echo

# --- 1. Create bucket ---
if aws s3api head-bucket --bucket "$REC_BUCKET" 2>/dev/null; then
  echo "Bucket already exists: $REC_BUCKET (continuing with harden steps)"
else
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$REC_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$REC_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  echo "Created $REC_BUCKET"
fi

# --- 2. Block Public Access (all ON — never public catalog here) ---
aws s3api put-public-access-block --bucket "$REC_BUCKET" --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "Block Public Access: all ON"

# --- 3. Default encryption SSE-S3 ---
aws s3api put-bucket-encryption --bucket "$REC_BUCKET" --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}, "BucketKeyEnabled": true}]
}'
echo "Default encryption: SSE-S3 (AES256)"

# --- 4. ACLs off ---
aws s3api put-bucket-ownership-controls --bucket "$REC_BUCKET" --ownership-controls \
  'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
echo "ObjectOwnership: BucketOwnerEnforced"

# --- 5. Deny non-TLS ---
if [[ ! -f "$POLICY_TMPL" ]]; then
  echo "Missing template: $POLICY_TMPL" >&2
  exit 1
fi
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
sed "s/RECORDINGS_BUCKET/${REC_BUCKET}/g" "$POLICY_TMPL" >"$TMP"
aws s3api put-bucket-policy --bucket "$REC_BUCKET" --policy "file://${TMP}"
echo "Bucket policy: DenyInsecureTransport"

echo
echo "Done. Set on control plane / nodes:"
echo "  PBX3_RECORDINGS_BUCKET=${REC_BUCKET}"
echo
echo "Next: attach gatekeeper IAM (ops):"
echo "  # fill template → managed policy pbx3-control-gatekeeper-recordings"
echo "  sed 's/RECORDINGS_BUCKET/${REC_BUCKET}/g' \\"
echo "    ${SCHEMA_DIR}/pbx3-control-gatekeeper-recordings.policy.json.tmpl > /tmp/gk-rec.json"
echo "  aws iam create-policy --policy-name pbx3-control-gatekeeper-recordings \\"
echo "    --policy-document file:///tmp/gk-rec.json"
echo "  aws iam attach-role-policy --role-name pbx3-control-gatekeeper \\"
echo "    --policy-arn arn:aws:iam::ACCOUNT:policy/pbx3-control-gatekeeper-recordings"
echo
echo "Verify BPA / encryption:"
echo "  aws s3api get-public-access-block --bucket ${REC_BUCKET}"
echo "  aws s3api get-bucket-encryption --bucket ${REC_BUCKET}"
echo
echo "NOTE: This bucket is PCI-shaped (private, TLS, SSE-S3) — not PCI-attested."
echo "      Do not store recordings in the org/catalog bucket (${ORG_BUCKET})."
