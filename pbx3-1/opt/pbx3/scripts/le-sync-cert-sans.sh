#!/bin/bash
# Re-issue Let's Encrypt certificate with an expanded SAN list (Option A sync).
# Usage: le-sync-cert-sans.sh <email> <fqdn1> [<fqdn2> ...]
# fqdn1 must match /opt/pbx3/etc/identity/le-domain (certbot --cert-name).
# Run as root. Requires certbot. Port 80 must be free for --standalone.

set -e
if [ $# -lt 2 ]; then
	echo "Usage: $0 <email> <fqdn1> [<fqdn2> ...]" >&2
	exit 1
fi
EMAIL="$1"
shift

LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"
if [ ! -f "$LE_DOMAIN_FILE" ]; then
	echo "No le-domain file at $LE_DOMAIN_FILE" >&2
	exit 1
fi
PRIMARY=$(tr -d '\n' < "$LE_DOMAIN_FILE")
if [ -z "$PRIMARY" ]; then
	echo "le-domain file is empty" >&2
	exit 1
fi
if [ "$1" != "$PRIMARY" ]; then
	echo "First FQDN must match le-domain ($PRIMARY); got: $1" >&2
	exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"

CERTBOT_D=()
for d in "$@"; do
	[ -n "$d" ] && CERTBOT_D+=( -d "$d" )
done

close_on_exit() {
	"$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

"$OPEN_SCRIPT"
certbot certonly --standalone --cert-name "$PRIMARY" "${CERTBOT_D[@]}" -m "$EMAIL" --expand --agree-tos --non-interactive 2>&1
"$APPLY_SCRIPT"
