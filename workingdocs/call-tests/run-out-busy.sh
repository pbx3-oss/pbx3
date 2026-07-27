#!/usr/bin/env bash
# out-busy-or-reject — Local originate to catcher ext; UAS returns 486 → PostDial.
#
# Far-end reject for Dial() (PJSIP catcher), not Egress PSTN. Asserts BUSY
# pathway: Voicemail (busy) or Busy() app on golden within timeout.
#
# Requires catcher UAS in 486 mode on CATCHER_PORT (run-pack starts it).
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
: "${CATCHER_DOMAIN:?}"
: "${CATCHER_EXT_A:=2000}"
: "${RECV_TIMEOUT:=60000}"

SU="${CATCHER_DOMAIN%%.*}"
EXT="${OUT_BUSY_EXT:-$CATCHER_EXT_A}"
WAIT_S=$(( RECV_TIMEOUT / 1000 ))
[[ "$WAIT_S" -lt 20 ]] && WAIT_S=20

echo "out-busy-or-reject: Local/${EXT}@${SU} → expect 486 → PostDial (Voicemail/Busy)"

# shellcheck disable=SC2086
$GOLDEN_SSH bash -s <<EOF
set -euo pipefail
EXT='${EXT}'
CTX='${SU}'
WAIT_S=${WAIT_S}

sudo asterisk -rx 'channel request hangup all' >/dev/null 2>&1 || true
sleep 0.5
sudo asterisk -rx "channel originate Local/\${EXT}@\${CTX} application Wait 12" >/dev/null &
OP=\$!

ok=0
seen_busy_dial=0
for i in \$(seq 1 "\$WAIT_S"); do
  CH=\$(sudo asterisk -rx 'core show channels concise' 2>/dev/null || true)
  if echo "\$CH" | grep -qiE 'Voicemail!|!Busy!|Playtones!busy'; then
    echo "out-busy-or-reject: PostDial busy/VM at t=\${i}s"
    ok=1
    break
  fi
  if echo "\$CH" | grep -qE "Dial!PJSIP/.*!\${EXT}|PJSIP/.*Busy"; then
    seen_busy_dial=1
  fi
  sleep 1
done

sudo asterisk -rx 'channel request hangup all' >/dev/null 2>&1 || true
wait "\$OP" 2>/dev/null || true

if [[ "\$ok" -eq 1 ]]; then
  echo "Successful call (Local → 486 → PostDial)"
  exit 0
fi
echo "FAIL: no Voicemail/Busy after Local/\${EXT} (seen_dial=\${seen_busy_dial})" >&2
sudo asterisk -rx 'core show channels concise' >&2 || true
exit 1
EOF
