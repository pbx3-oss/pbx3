#!/usr/bin/env bash
# DID lab smoke — Peer 99 UAC → Magrathea Number route → golden openroute.
#
# Usage (on 98.82.58.59):
#   ./run-did-lab-in.sh                 # one call to DID_LAB
#   DID_LAB=01924234567 ./run-did-lab-in.sh
#
# Requires: Peer gwid 99 = this host EIP; Number route + golden Ingress for DID.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
# Preserve CLI overrides (lab.env must not clobber DID_LAB=… ./run-did-lab-in.sh)
_DID_LAB_CLI="${DID_LAB-}"
_LOCAL_IP_CLI="${LOCAL_IP-}"
# shellcheck disable=SC1091
source ./lab.env
[[ -n "$_DID_LAB_CLI" ]] && DID_LAB="$_DID_LAB_CLI"
[[ -n "$_LOCAL_IP_CLI" ]] && LOCAL_IP="$_LOCAL_IP_CLI"

: "${SBC_HOST:?}"
: "${SBC_PORT:=5060}"
: "${DID_LAB:=01924234567}"
: "${LOCAL_IP:=}"
: "${LOCAL_PORT:=5061}"
: "${RECV_TIMEOUT:=60000}"

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?}"

mkdir -p notes
LOG="notes/did-lab-in-$(date +%Y%m%d-%H%M%S).log"

echo "did-lab-in: INVITE $DID_LAB@$SBC_HOST from $LOCAL_IP:$LOCAL_PORT"
sipp "$SBC_HOST:$SBC_PORT" \
  -i "$LOCAL_IP" -p "$LOCAL_PORT" \
  -sf scenarios/in-open-ext.xml \
  -s "$DID_LAB" \
  -m 1 \
  -recv_timeout "$RECV_TIMEOUT" \
  -timeout_error \
  -trace_err -error_file notes/did-lab-in-err.log \
  >"$LOG" 2>&1

grep -E "Successful call|Failed call|Abort|Timeout" "$LOG" | tail -10
if grep -q "Successful call" "$LOG"; then
  echo "did-lab-in: GREEN"
  exit 0
fi
echo "did-lab-in: FAIL — see $LOG" >&2
exit 1
