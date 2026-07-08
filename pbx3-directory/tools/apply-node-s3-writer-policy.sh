#!/usr/bin/env bash
# Create or update a PBX node IAM policy (S3 writer + object tagging for backup lifecycle).
#
# Usage:
#   ./apply-node-s3-writer-policy.sh POLICY_NAME POLICY_JSON_FILE
# Example (golden):
#   ./apply-node-s3-writer-policy.sh pbx3-node-08jzwn-s3-writer \
#     ../schema/pbx3-node-s3-writer.policy.json
#
# Requires: aws CLI with iam:CreatePolicyVersion (or CreatePolicy) — run from Mac/ops, not EC2 node.

set -euo pipefail

POLICY_NAME="${1:?policy name required (e.g. pbx3-node-08jzwn-s3-writer)}"
POLICY_FILE="${2:?path to policy JSON required}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "policy file not found: $POLICY_FILE" >&2
  exit 1
fi

ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)"
if [[ "$ARN" == *":assumed-role/pbx3-node-"* ]]; then
  echo "ERROR: AWS identity is a PBX EC2 node role ($ARN)." >&2
  echo "Run from your Mac (or ops workstation) with IAM admin credentials." >&2
  exit 1
fi

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT}:policy/${POLICY_NAME}"

if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "Updating IAM policy ${POLICY_ARN} ..."
  if ! aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default 2>"${POLICY_FILE}.err"; then
    if grep -q LimitExceeded "${POLICY_FILE}.err" 2>/dev/null; then
      echo "Policy version limit reached — deleting oldest non-default version and retrying ..."
      OLD_VERSION="$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
        --query 'Versions[?IsDefaultVersion==`false`] | sort_by(@, &CreateDate) | [0].VersionId' \
        --output text)"
      if [[ -n "$OLD_VERSION" && "$OLD_VERSION" != "None" ]]; then
        aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$OLD_VERSION"
        aws iam create-policy-version \
          --policy-arn "$POLICY_ARN" \
          --policy-document "file://${POLICY_FILE}" \
          --set-as-default
      else
        cat "${POLICY_FILE}.err" >&2
        rm -f "${POLICY_FILE}.err"
        exit 1
      fi
    else
      cat "${POLICY_FILE}.err" >&2
      rm -f "${POLICY_FILE}.err"
      exit 1
    fi
  fi
  rm -f "${POLICY_FILE}.err"
  echo "Done. Attached roles pick up the new default version immediately."
else
  echo "Creating IAM policy ${POLICY_NAME} ..."
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${POLICY_FILE}"
  echo "Created ${POLICY_ARN}. Attach to the EC2 instance role in IAM console."
fi
