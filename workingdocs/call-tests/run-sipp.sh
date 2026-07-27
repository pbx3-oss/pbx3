#!/usr/bin/env bash
# Run a named L1 SIPp scenario against Magrathea VIP (Mac-only lab).
# Usage: ./run-sipp.sh <scenario-id>
# Example: ./run-sipp.sh in-open-ext
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario-id>" >&2
  echo "  scenarios: $(ls scenarios/*.xml 2>/dev/null | xargs -n1 basename | sed 's/.xml$//' | tr '\n' ' ')" >&2
  exit 1
fi

SF="scenarios/${SCENARIO}.xml"
if [[ ! -f "$SF" ]]; then
  echo "Missing $SF" >&2
  exit 1
fi

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env — copy lab.env.example and edit:" >&2
  echo "  cp lab.env.example lab.env" >&2
  exit 1
fi

# shellcheck disable=SC1091
source ./lab.env

: "${SBC_HOST:?}"
: "${SBC_PORT:=5060}"
: "${DID:?}"
: "${LOCAL_PORT:=5061}"
: "${CALLS:=1}"
: "${RATE:=1}"
: "${RECV_TIMEOUT:=60000}"

if ! command -v sipp >/dev/null 2>&1; then
  echo "sipp not found — install (Mac: brew install sipp)" >&2
  exit 1
fi

if [[ -z "${LOCAL_IP:-}" ]]; then
  LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
fi

mkdir -p notes

SIPP_ARGS=(
  "$SBC_HOST"
  -p "$LOCAL_PORT"
  -sf "$SF"
  -s "$DID"
  -m "$CALLS"
  -r "$RATE"
  -recv_timeout "$RECV_TIMEOUT"
  -timeout_error
  -trace_err
  -trace_msg
  -message_file "notes/${SCENARIO}-msg.log"
  -error_file "notes/${SCENARIO}-err.log"
)

if [[ -n "${LOCAL_IP:-}" ]]; then
  SIPP_ARGS+=(-i "$LOCAL_IP")
else
  echo "WARN: LOCAL_IP unset — SIPp may fail to bind Contact; set in lab.env or en0." >&2
fi

echo "SIPp ${SCENARIO} → sip:${DID}@${SBC_HOST}:${SBC_PORT}  (calls=${CALLS}, local=${LOCAL_IP:-auto})"
echo "See README § Scenarios for lab preconditions. Answer expected dest within ${RECV_TIMEOUT}ms."
exec sipp "${SIPP_ARGS[@]}"
