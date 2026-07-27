#!/usr/bin/env bash
# Run SIPp catcher against Magrathea VIP.
# Usage: ./run-catcher.sh [register|uas]
#   register — one-shot REGISTER smoke
#   uas      — REGISTER once, then stay up auto-answering INVITEs (Ctrl-C to stop)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

MODE="${1:-uas}"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env — copy lab.env.example and set CATCHER_* vars" >&2
  exit 1
fi

# Allow caller (run-pack) to override CATCHER_* before source
_OV_USER="${CATCHER_USER:-}"
_OV_PASS="${CATCHER_PASS:-}"
_OV_PORT="${CATCHER_PORT:-}"
_OV_DOMAIN="${CATCHER_DOMAIN:-}"

# shellcheck disable=SC1091
source ./lab.env

[[ -n "$_OV_USER" ]] && CATCHER_USER="$_OV_USER"
[[ -n "$_OV_PASS" ]] && CATCHER_PASS="$_OV_PASS"
[[ -n "$_OV_PORT" ]] && CATCHER_PORT="$_OV_PORT"
[[ -n "$_OV_DOMAIN" ]] && CATCHER_DOMAIN="$_OV_DOMAIN"

: "${SBC_HOST:?}"
: "${CATCHER_DOMAIN:?}"
: "${CATCHER_USER:?}"
: "${CATCHER_PASS:?}"
: "${CATCHER_PORT:=5070}"
: "${RECV_TIMEOUT:=60000}"

if ! command -v sipp >/dev/null 2>&1; then
  echo "sipp not found — install (Mac: brew install sipp)" >&2
  exit 1
fi

if [[ -z "${LOCAL_IP:-}" ]]; then
  LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
fi

mkdir -p notes

common_bind=()
if [[ -n "${LOCAL_IP:-}" ]]; then
  common_bind+=(-i "$LOCAL_IP")
else
  echo "WARN: LOCAL_IP unset — set in lab.env" >&2
fi

run_register() {
  echo "SIPp catcher register → ${CATCHER_USER}@${CATCHER_DOMAIN} via ${SBC_HOST} (local :${CATCHER_PORT})"
  sipp "$SBC_HOST" \
    -p "$CATCHER_PORT" \
    "${common_bind[@]}" \
    -sf scenarios/catcher-register.xml \
    -au "$CATCHER_USER" \
    -ap "$CATCHER_PASS" \
    -key domain "$CATCHER_DOMAIN" \
    -key user "$CATCHER_USER" \
    -m 1 \
    -recv_timeout "$RECV_TIMEOUT" \
    -timeout_error \
    -trace_err \
    -trace_msg \
    -message_file "notes/catcher-register-msg.log" \
    -error_file "notes/catcher-register-err.log"
}

run_answer() {
  local calls="${CATCHER_CALLS:-9999}"
  echo "SIPp catcher answer → waiting INVITE as ${CATCHER_USER} on :${CATCHER_PORT} (m=${calls})"
  # -l 1: one call at a time; do not re-REGISTER between answers
  exec sipp \
    -p "$CATCHER_PORT" \
    "${common_bind[@]}" \
    -sf scenarios/catcher-answer.xml \
    -key user "$CATCHER_USER" \
    -m "$calls" \
    -l 1 \
    -recv_timeout "$RECV_TIMEOUT" \
    -trace_err \
    -trace_msg \
    -message_file "notes/catcher-answer-msg.log" \
    -error_file "notes/catcher-answer-err.log"
}

case "$MODE" in
  register)
    run_register
    ;;
  uas)
    run_register
    run_answer
    ;;
  *)
    echo "Usage: $0 [register|uas]" >&2
    exit 1
    ;;
esac
