#!/bin/bash
# Offline test: ensure-asterisk-logger-channels.sh splits security from messages.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/ensure-asterisk-logger-channels.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/logger.conf" <<'EOF'
[general]
;dateformat=%F %T .

[logfiles]
messages => security,notice,warning,error
console => notice,warning,error
EOF

export PBX3_LOGGER_CONF="$TMP/logger.conf"
export PBX3_ASTERISK_SECURITY_LOG="$TMP/security"
export PBX3_LOGGER_RELOAD=0
export PBX3_ASTERISK_EXEC=/bin/true

"$SCRIPT"

grep -qx 'messages => notice,warning,error,verbose' "$TMP/logger.conf"
grep -qx 'security => security' "$TMP/logger.conf"
! grep -qE '^[[:space:]]*messages[[:space:]]*=>.*security' "$TMP/logger.conf"
test -f "$TMP/security"

# Idempotent second run
"$SCRIPT"
count=$(grep -cE '^[[:space:]]*security[[:space:]]*=>' "$TMP/logger.conf")
[[ "$count" -eq 1 ]]

echo "ensure-asterisk-logger-channels-test: OK"
