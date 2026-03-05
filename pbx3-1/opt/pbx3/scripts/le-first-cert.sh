#!/bin/bash
# First-time Let's Encrypt certificate: open port 80, run certbot certonly --standalone, write le-domain, apply cert, close 80.
# Usage: le-first-cert.sh <fqdn> <email>
# Run as root. Requires certbot. Port 80 must be free for certbot --standalone (nothing else listening).

set -e
if [ $# -lt 2 ]; then
    echo "Usage: $0 <fqdn> <email>" >&2
    exit 1
fi
FQDN="$1"
EMAIL="$2"
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"
LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"

close_on_exit() {
    "$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

"$OPEN_SCRIPT"
certbot certonly --standalone -d "$FQDN" -m "$EMAIL" --agree-tos --non-interactive
mkdir -p "$(dirname "$LE_DOMAIN_FILE")"
echo "$FQDN" > "$LE_DOMAIN_FILE"
"$APPLY_SCRIPT"
