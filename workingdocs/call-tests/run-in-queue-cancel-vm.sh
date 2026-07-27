#!/usr/bin/env bash
# in-queue-cancel-vm — SIPp DID→queue + CLI assert Voicemail after agent 486.
# Catcher must already be in uas-486 (run-pack). Lab-state: queue.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./lab.env

: "${GOLDEN_SSH:?}"
: "${RECV_TIMEOUT:=60000}"

WAIT_S=$(( RECV_TIMEOUT / 1000 ))
[[ "$WAIT_S" -lt 25 ]] && WAIT_S=25

# shellcheck disable=SC2086
$GOLDEN_SSH 'rm -f /tmp/in-queue-cancel-vm-vmseen'

./run-sipp.sh in-queue-cancel-vm catcher &
SIPP_PID=$!

ok=0
for i in $(seq 1 "$WAIT_S"); do
  # shellcheck disable=SC2086
  if $GOLDEN_SSH "sudo asterisk -rx 'core show channels concise'" 2>/dev/null | grep -qiE 'Voicemail!'; then
    echo "in-queue-cancel-vm: Voicemail seen at t=${i}s"
    # shellcheck disable=SC2086
    $GOLDEN_SSH 'touch /tmp/in-queue-cancel-vm-vmseen' || true
    ok=1
    break
  fi
  if ! kill -0 "$SIPP_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

SIPP_RC=0
wait "$SIPP_PID" || SIPP_RC=$?

if [[ "$SIPP_RC" -ne 0 ]]; then
  echo "FAIL: SIPp in-queue-cancel-vm rc=$SIPP_RC" >&2
  exit 1
fi
if [[ "$ok" -ne 1 ]]; then
  echo "FAIL: queue→486→failover did not reach Voicemail" >&2
  exit 1
fi
echo "Successful call (queue agent 486 → failover → Voicemail)"
exit 0
