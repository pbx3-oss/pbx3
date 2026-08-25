#!/bin/bash
# Remove the managed port-80 rule from the firewall (used after Let's Encrypt renewal).
# Prefers UFW; Shorewall fallback for pre-cutover hosts.
# Called by le-renew-with-80.sh. Run as root.

set -e
MARKER="LE renewal (managed)"
FW_RULES="/etc/shorewall/pbx3_rules"
FW_RULES6="/etc/shorewall6/pbx3_rules6"

ufw_active() {
    command -v ufw >/dev/null 2>&1 || return 1
    ufw status 2>/dev/null | grep -qi '^Status: active'
}

if ufw_active; then
    while true; do
        num=$(ufw status numbered 2>/dev/null | sed -n "s/^\[\s*\([0-9][0-9]*\)\].*${MARKER}.*/\1/p" | head -1)
        [ -n "$num" ] || break
        ufw --force delete "$num" >/dev/null
    done
    exit 0
fi

remove_managed() {
    local file="$1"
    [ ! -f "$file" ] && return
    if grep -qF "$MARKER" "$file" 2>/dev/null; then
        grep -vF "$MARKER" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
}

remove_managed "$FW_RULES"
remove_managed "$FW_RULES6"

if command -v shorewall >/dev/null 2>&1; then
    /sbin/shorewall check 2>/dev/null && /sbin/shorewall restart 2>/dev/null || true
fi
if command -v shorewall6 >/dev/null 2>&1; then
    /sbin/shorewall6 check 2>/dev/null && /sbin/shorewall6 restart 2>/dev/null || true
fi
