#!/usr/bin/env bash
# Extension-platform smoke: catcher A dials catcher B (same tenant).
# Usage: ./run-phone-a-b.sh
# Prefers local VM / Mac phone UAC — not the Peer-99 catcher host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./lab.env

: "${CATCHER_USER:?}"
: "${CATCHER_PASS:?}"
: "${CATCHER_USER_B:?}"
: "${CATCHER_PASS_B:?}"
: "${CATCHER_PORT:=5070}"
: "${CATCHER_PORT_B:=5071}"
: "${CATCHER_EXT_B:=2001}"

pkill -f 'sipp ' 2>/dev/null || true
sleep 0.3
mkdir -p notes

cleanup() {
  if [[ -n "${BPID:-}" ]]; then
    kill "$BPID" 2>/dev/null || true
  fi
  pkill -f 'sipp ' 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting UAS B ${CATCHER_USER_B} (ext ${CATCHER_EXT_B}) on :${CATCHER_PORT_B}"
CATCHER_USER="$CATCHER_USER_B" CATCHER_PASS="$CATCHER_PASS_B" CATCHER_PORT="$CATCHER_PORT_B" \
  ./run-catcher.sh uas >notes/phone-b-uas.log 2>&1 &
BPID=$!
sleep 2
if ! kill -0 "$BPID" 2>/dev/null; then
  echo "UAS B failed to start:" >&2
  tail -40 notes/phone-b-uas.log >&2 || true
  exit 1
fi

echo "A ${CATCHER_USER} dials ${CATCHER_EXT_B}"
OUT_DIGITS="$CATCHER_EXT_B" ./run-sipp.sh out-egress-ok
