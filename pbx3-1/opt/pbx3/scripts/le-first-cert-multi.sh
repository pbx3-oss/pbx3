#!/bin/bash
# First-time Let's Encrypt certificate with multiple SANs (Option A).
# Usage: le-first-cert-multi.sh <primary_fqdn> <email> [additional_san_fqdn ...]
# primary_fqdn is written to /opt/pbx3/etc/identity/le-domain (Let's Encrypt live dir name).
# Run as root. Requires certbot. Port 80 must be free for certbot --standalone.

set -e
if [ $# -lt 2 ]; then
	echo "Usage: $0 <primary_fqdn> <email> [additional_san_fqdn ...]" >&2
	exit 1
fi
PRIMARY="$1"
EMAIL="$2"
shift 2

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"
LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"

CERTBOT_D=( -d "$PRIMARY" )
for d in "$@"; do
	[ -n "$d" ] && CERTBOT_D+=( -d "$d" )
done

close_on_exit() {
	"$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

"$OPEN_SCRIPT"
certbot certonly --standalone "${CERTBOT_D[@]}" -m "$EMAIL" --agree-tos --non-interactive
mkdir -p "$(dirname "$LE_DOMAIN_FILE")"
echo "$PRIMARY" > "$LE_DOMAIN_FILE"
"$APPLY_SCRIPT"
