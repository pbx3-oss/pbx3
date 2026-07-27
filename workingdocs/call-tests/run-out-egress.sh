#!/usr/bin/env bash
# out-egress-ok — Local originate on golden → SIPP_MAIN → Egress → Magrathea DID.
#
# Why not SIPp phone UAC from the SIPp EC2? That host EIP is Peer gwid 99
# (FROM_CARRIER). Phone INVITEs from the same IP get "404 No inbound route".
# Local/ originate exercises the same OutRoute/OutVoip dial string without
# crossing that OpenSIPS carrier match.
#
# Assert: within RECV_TIMEOUT, see Dial(PJSIP/<digits>@Egress) bridged (Up).
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
: "${OUT_DIGITS:=01924910444}"
: "${RECV_TIMEOUT:=60000}"
: "${CATCHER_DOMAIN:?}"

SU="${CATCHER_DOMAIN%%.*}"
WAIT_S=$(( RECV_TIMEOUT / 1000 ))
[[ "$WAIT_S" -lt 15 ]] && WAIT_S=15

./lab-state.sh ensure-outroute >/dev/null

echo "out-egress-ok: Local/${OUT_DIGITS}@${SU} → Egress (wait ≤${WAIT_S}s)"

# shellcheck disable=SC2086
$GOLDEN_SSH bash -s <<EOF
set -euo pipefail
OUT='${OUT_DIGITS}'
CTX='${SU}'
WAIT_S=${WAIT_S}

sudo asterisk -rx "dialplan add extension _XXXXX.,1,agi(pbx3cagi,OutRoute,SIPP_MAIN,\${CTX},,,) into \${CTX} replace" >/dev/null

# Hang up leftovers; start originate (CLI returns immediately)
sudo asterisk -rx 'channel request hangup all' >/dev/null 2>&1 || true
sleep 0.5
sudo asterisk -rx "channel originate Local/\${OUT}@\${CTX} application Wait 8" >/dev/null &
OP=\$!

ok=0
for i in \$(seq 1 "\$WAIT_S"); do
  CH=\$(sudo asterisk -rx 'core show channels concise' 2>/dev/null || true)
  if echo "\$CH" | grep -qE "Dial!PJSIP/\${OUT}@Egress|PJSIP/Egress-.*!\${OUT}"; then
    # Prefer answered/Up Egress leg
    if echo "\$CH" | grep -qE "PJSIP/Egress-.*!Up!"; then
      echo "out-egress-ok: Egress Up at t=\${i}s"
      ok=1
      break
    fi
    # Ringing counts as pathway OK if we later get Up; keep waiting briefly
    echo "out-egress-ok: Egress dial seen at t=\${i}s (waiting Up)"
  fi
  sleep 1
done

sudo asterisk -rx 'channel request hangup all' >/dev/null 2>&1 || true
wait "\$OP" 2>/dev/null || true

if [[ "\$ok" -eq 1 ]]; then
  echo "Successful call (AMI Local → Egress)"
  exit 0
fi
echo "FAIL: no PJSIP/Egress Up for \${OUT} within \${WAIT_S}s" >&2
sudo asterisk -rx 'core show channels concise' >&2 || true
exit 1
EOF
