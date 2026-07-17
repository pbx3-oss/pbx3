#!/usr/bin/env bash
# Ship rotated control-host logs to org S3 (Phase 4).
# Keys: s3://$PBX3_ORG_BUCKET/control/$PBX3_CONTROL_ID/logs/{class}/{stamp}/{basename}
# Classes: syslog | nginx
#
# Usage: sudo /usr/local/bin/pbx3-control-ship-logs [--limit N] [--dry-run]
# Env: /etc/pbx3-gatekeeper/log-ship.env (or PBX3_LOG_SHIP_ENV)

set -euo pipefail
shopt -s nullglob

ENV_FILE="${PBX3_LOG_SHIP_ENV:-/etc/pbx3-gatekeeper/log-ship.env}"
[[ -f "$ENV_FILE" ]] && # shellcheck disable=SC1090
  source "$ENV_FILE"

LIMIT=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="${2:-}"; shift 2 ;;
    --limit=*)
      LIMIT="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: $0 [--limit N] [--dry-run]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

BUCKET="${PBX3_ORG_BUCKET:-}"
CTRL_ID="${PBX3_CONTROL_ID:-control}"
ENABLED="${PBX3_LOG_UPLOAD_ENABLED:-true}"
STATE_PATH="${PBX3_LOG_SHIP_STATE:-/var/lib/pbx3-gatekeeper/log-ship-state.json}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

if [[ "${ENABLED}" != "true" && "${ENABLED}" != "1" ]]; then
  echo "upload disabled"; exit 0
fi
if [[ -z "$BUCKET" ]]; then
  echo "PBX3_ORG_BUCKET unset" >&2; exit 0
fi
command -v aws >/dev/null || { echo "aws CLI required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

mkdir -p "$(dirname "$STATE_PATH")"
[[ -f "$STATE_PATH" ]] || echo '{}' >"$STATE_PATH"

fingerprint() {
  local path=$1 ino size mtime
  ino=$(stat -c '%i' "$path"); size=$(stat -c '%s' "$path"); mtime=$(stat -c '%Y' "$path")
  printf '%s' "${path}|${ino}|${size}|${mtime}" | sha256sum | awk '{print $1}'
}
stamp_for() {
  local mtime; mtime=$(stat -c '%Y' "$1")
  date -u -d "@${mtime}" +%Y%m%dT%H%M%SZ
}

POLICY_KEY="control/${CTRL_ID}/logs/policy.json"
if [[ "$DRY_RUN" -eq 0 ]]; then
  if ! aws s3api head-object --bucket "$BUCKET" --key "$POLICY_KEY" >/dev/null 2>&1; then
    jq -n '{schema_version:1, classes:{syslog:30, nginx:30}, updated_at:(now|todateiso8601)}' \
      | aws s3 cp - "s3://${BUCKET}/${POLICY_KEY}" --content-type application/json
  fi
fi

candidates=()
for path in /var/log/syslog.[0-9]* /var/log/syslog.*.gz; do
  [[ -f "$path" && -r "$path" ]] || continue
  base=$(basename "$path")
  [[ "$base" =~ ^syslog\.[0-9] ]] || continue
  candidates+=("syslog	$path")
done
for path in /var/log/nginx/*.log.[0-9]* /var/log/nginx/*.log.*.gz; do
  [[ -f "$path" && -r "$path" ]] || continue
  candidates+=("nginx	$path")
done

IFS=$'\n' sorted=($(printf '%s\n' "${candidates[@]:-}" | sort -u)); unset IFS

uploaded=0; skipped=0; errors=0; count=0
for line in "${sorted[@]:-}"; do
  [[ -z "$line" ]] && continue
  class=${line%%$'\t'*}; path=${line#*$'\t'}
  [[ -f "$path" ]] || continue
  if [[ -n "$LIMIT" && "$count" -ge "$LIMIT" ]]; then break; fi
  count=$((count + 1))
  fp=$(fingerprint "$path")
  if jq -e --arg fp "$fp" 'has($fp)' "$STATE_PATH" >/dev/null 2>&1; then
    skipped=$((skipped + 1)); continue
  fi
  stamp=$(stamp_for "$path"); base=$(basename "$path")
  key="control/${CTRL_ID}/logs/${class}/${stamp}/${base}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN $path -> s3://${BUCKET}/${key}"; uploaded=$((uploaded + 1)); continue
  fi
  if aws s3 cp "$path" "s3://${BUCKET}/${key}" --only-show-errors \
    && aws s3api put-object-tagging --bucket "$BUCKET" --key "$key" \
      --tagging "TagSet=[{Key=class,Value=${class}}]" 2>/dev/null; then
    :
  elif aws s3 cp "$path" "s3://${BUCKET}/${key}" --only-show-errors; then
    echo "warn: no tag on $key" >&2
  else
    echo "error: $path" >&2; errors=$((errors + 1)); continue
  fi
  tmp=$(mktemp)
  jq --arg fp "$fp" --arg path "$path" --arg class "$class" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.[$fp]={path:$path,class:$class,shipped_at:$at}' "$STATE_PATH" >"$tmp"
  mv "$tmp" "$STATE_PATH"
  uploaded=$((uploaded + 1))
  echo "uploaded $path -> s3://${BUCKET}/${key}"
done
echo "Log ship: ${uploaded} uploaded, ${skipped} skipped, ${errors} errors"
[[ "$errors" -eq 0 ]] || exit 1
