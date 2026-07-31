#!/usr/bin/env bash
# DID lab outbound smoke — sippuac phone UAC → OutRoute → Egress → Peer 99 UAS.
#
# Usage (on sippuac / extension platform — NOT Peer 99):
#   ./run-did-lab-out.sh
#   OUT_DIGITS=01924234567 ./run-did-lab-out.sh
#
# Requires: Peer 99 UAS listening (./run-peer-pstn-uas.sh start on catcher);
# Magrathea outbound gwlist prefers gwid 99; SIPP_MAIN / _XXXXX. → Egress on pb0wsk.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
_OUT_CLI="${OUT_DIGITS-}"
_DID_CLI="${DID_LAB-}"
_LOCAL_IP_CLI="${LOCAL_IP-}"
_PUBLIC_IP_CLI="${PUBLIC_IP-}"
# shellcheck disable=SC1091
source ./lab.env
if [[ -f soak-phones.env ]]; then
  # shellcheck disable=SC1091
  source ./soak-phones.env
fi
[[ -n "$_OUT_CLI" ]] && OUT_DIGITS="$_OUT_CLI"
[[ -n "$_DID_CLI" ]] && DID_LAB="$_DID_CLI"
[[ -n "$_LOCAL_IP_CLI" ]] && LOCAL_IP="$_LOCAL_IP_CLI"
[[ -n "$_PUBLIC_IP_CLI" ]] && PUBLIC_IP="$_PUBLIC_IP_CLI"

: "${SBC_HOST:?}"
: "${CATCHER_DOMAIN:?}"
: "${OUT_DIGITS:=${DID_LAB:-01924234567}}"
: "${LOCAL_IP:=}"
: "${PUBLIC_IP:=}"
: "${RECV_TIMEOUT:=60000}"
: "${SOAK_DOMAIN:=${CATCHER_DOMAIN}}"

# Prefer soak dialer 0; else CATCHER_USER as phone (only if not on Peer 99 EIP)
: "${DIALER_0_USER:=}"
: "${DIALER_0_PASS:=}"
: "${DIALER_0_EXT:=}"

if [[ -n "${DIALER_0_USER}" ]]; then
  USER="$DIALER_0_USER"
  PASS="$DIALER_0_PASS"
else
  : "${CATCHER_USER:?}"
  : "${CATCHER_PASS:?}"
  USER="$CATCHER_USER"
  PASS="$CATCHER_PASS"
fi

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?}"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null | tr -d '[:space:]' || true)"
fi
: "${PUBLIC_IP:?}"

UAC_PORT="${DID_LAB_OUT_PORT:-5410}"
HOLD_MS="${DID_LAB_HOLD_MS:-8000}"

mkdir -p notes/did-out
sed "s/HOLD_PLACEHOLDER/${HOLD_MS}/g" scenarios/soak-dial.xml >notes/did-out/dial.xml

echo "did-lab-out: REGISTER $USER@$SOAK_DOMAIN then INVITE $OUT_DIGITS (contact=$PUBLIC_IP)"

sipp "$SBC_HOST" \
  -i "$LOCAL_IP" -p "$UAC_PORT" \
  -sf scenarios/soak-register.xml \
  -au "$USER" -ap "$PASS" \
  -key domain "$SOAK_DOMAIN" \
  -key user "$USER" \
  -key contact_ip "$PUBLIC_IP" \
  -m 1 -recv_timeout "$RECV_TIMEOUT" -timeout_error \
  -trace_err -error_file notes/did-out/reg-err.log \
  >/dev/null 2>&1

sipp "$SBC_HOST" \
  -i "$LOCAL_IP" -p "$UAC_PORT" \
  -sf notes/did-out/dial.xml \
  -au "$USER" -ap "$PASS" \
  -key domain "$SOAK_DOMAIN" \
  -key user "$USER" \
  -key digits "$OUT_DIGITS" \
  -key contact_ip "$PUBLIC_IP" \
  -m 1 -recv_timeout "$RECV_TIMEOUT" -timeout_error \
  -trace_err -error_file notes/did-out/dial-err.log \
  >notes/did-out/dial.log 2>&1

grep -E "Successful call|Failed call|Abort|Timeout" notes/did-out/dial.log | tail -10
if grep -q "Successful call" notes/did-out/dial.log; then
  echo "did-lab-out: GREEN"
  exit 0
fi
echo "did-lab-out: FAIL — see notes/did-out/" >&2
exit 1
