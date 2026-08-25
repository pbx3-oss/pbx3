#!/bin/bash
# Open port 80 in UFW for Let's Encrypt HTTP-01 (issuance/renewal).
# Called by le-renew-with-80.sh. Run as root.

set -e
MARKER="LE renewal (managed)"

command -v ufw >/dev/null 2>&1 || { echo "le-port80-open: ufw not installed" >&2; exit 1; }

if ufw status 2>/dev/null | grep -qF "$MARKER"; then
    exit 0
fi
ufw allow 80/tcp comment "$MARKER"
