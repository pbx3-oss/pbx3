#!/bin/bash
# Open port 80 in the firewall for Let's Encrypt HTTP-01 (issuance/renewal).
# Prefers UFW (home firewall product path); Shorewall fallback for pre-cutover hosts.
# Called by le-renew-with-80.sh. Run as root.

set -e
MARKER="LE renewal (managed)"
FW_RULES="/etc/shorewall/pbx3_rules"
FW_RULES6="/etc/shorewall6/pbx3_rules6"
RULE='ACCEPT net $FW tcp 80 - - # LE renewal (managed)'

ufw_active() {
    command -v ufw >/dev/null 2>&1 || return 1
    ufw status 2>/dev/null | grep -qi '^Status: active'
}

if ufw_active; then
    if ufw status 2>/dev/null | grep -qF "$MARKER"; then
        exit 0
    fi
    ufw allow 80/tcp comment "$MARKER"
    exit 0
fi

append_if_missing() {
    local file="$1"
    local line="$2"
    if [ ! -f "$file" ]; then
        echo "$line" >> "$file"
        return
    fi
    if grep -qF "$MARKER" "$file" 2>/dev/null; then
        return
    fi
    echo "$line" >> "$file"
}

append_if_missing "$FW_RULES" "$RULE"
append_if_missing "$FW_RULES6" "$RULE"

if command -v shorewall >/dev/null 2>&1; then
    /sbin/shorewall check 2>/dev/null && /sbin/shorewall restart 2>/dev/null || true
fi
if command -v shorewall6 >/dev/null 2>&1; then
    /sbin/shorewall6 check 2>/dev/null && /sbin/shorewall6 restart 2>/dev/null || true
fi
