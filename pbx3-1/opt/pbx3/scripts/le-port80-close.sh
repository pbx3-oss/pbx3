#!/bin/bash
# Remove the managed port-80 UFW rule after Let's Encrypt renewal.
# Called by le-renew-with-80.sh. Run as root.

set -e
MARKER="LE renewal (managed)"

command -v ufw >/dev/null 2>&1 || exit 0

while true; do
    num=$(ufw status numbered 2>/dev/null | sed -n "s/^\[\s*\([0-9][0-9]*\)\].*${MARKER}.*/\1/p" | head -1)
    [ -n "$num" ] || break
    ufw --force delete "$num" >/dev/null
done
