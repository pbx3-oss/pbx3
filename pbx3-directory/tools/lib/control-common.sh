# shellcheck shell=bash
# Shared helpers for the Lab / try-it control-host installer (D1).
# Source from tools/install-control-host.sh and sibling scripts.

set -euo pipefail

control_log() { printf 'control: %s\n' "$*"; }
control_err() { printf 'control: ERROR: %s\n' "$*" >&2; }

control_require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    control_err "run as root (sudo $0 …)"
    exit 1
  fi
}

control_require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      control_err "required command not found: $cmd"
      exit 1
    fi
  done
}

# Neutral fleet slug → org bucket name (OPS_S3_RUNBOOK design note).
# Usage: control_org_bucket_from_slug acme  →  acme-pbx3
control_org_bucket_from_slug() {
  local raw slug bucket
  raw="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  slug="$(printf '%s' "$raw" | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
  if [[ -z "$slug" ]]; then
    control_err "fleet slug is empty"
    return 1
  fi
  if [[ ! "$slug" =~ ^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$ ]]; then
    control_err "fleet slug must be 1–32 chars, lowercase letters/digits/hyphen (got: $slug)"
    return 1
  fi
  if [[ "$slug" == *pbx3 ]]; then
    bucket="$slug"
  else
    bucket="${slug}-pbx3"
  fi
  if (( ${#bucket} < 3 || ${#bucket} > 63 )); then
    control_err "org bucket name length invalid: $bucket"
    return 1
  fi
  printf '%s\n' "$bucket"
}

control_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Empty catalog (HoR shape). Same keys as schema/instance-index.json with no instances.
control_empty_catalog_json() {
  local org_id="${1:-}"
  jq -n --arg now "$(control_now_iso)" --arg org "$org_id" '
    {version: 1, updated_at: $now, instances: []}
    | if $org != "" then .org_id = $org else . end
  '
}

# Default LAN IPv4 (first src on default route). Empty if undetectable.
control_detect_ipv4() {
  local ip=""
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')" || true
  if [[ -z "$ip" ]]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')" || true
  fi
  printf '%s' "$ip"
}

# Prompt when stdin is a TTY and the env var is unset. Non-interactive: require env or default.
# control_prompt VAR "Question" "default"
control_prompt() {
  local var="$1" question="$2" default="${3:-}"
  local cur ans
  cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ -t 0 ]]; then
    if [[ -n "$default" ]]; then
      read -r -p "$question [$default]: " ans || true
    else
      read -r -p "$question: " ans || true
    fi
    ans="${ans:-$default}"
    printf -v "$var" '%s' "$ans"
    return 0
  fi
  if [[ -n "$default" ]]; then
    printf -v "$var" '%s' "$default"
    return 0
  fi
  control_err "non-interactive: set $var"
  return 1
}

control_prompt_secret() {
  local var="$1" question="$2"
  local cur ans
  cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    control_err "non-interactive: set $var"
    return 1
  fi
  read -r -s -p "$question: " ans || true
  echo
  if [[ -z "$ans" ]]; then
    control_err "password cannot be empty"
    return 1
  fi
  printf -v "$var" '%s' "$ans"
}

control_rand_hex() {
  openssl rand -hex "${1:-32}"
}

control_rand_token() {
  openssl rand -hex 32
}
