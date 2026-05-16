#!/bin/bash
# First-time Let's Encrypt certificate with multiple SANs (Option A, HTTP-01 webroot by default).
# Usage: le-first-cert-multi.sh <primary_fqdn> <email> [additional_san_fqdn ...]
# primary_fqdn is written to /opt/pbx3/etc/identity/le-domain (Let's Encrypt live dir name).
# Run as root. Requires certbot, nginx ACME site, port 80 reachable.
# PBX3_LE_STAGING=1 or PBX3_LE_STANDALONE=1 — see le-acme-common.sh

set -e
if [ $# -lt 2 ]; then
	echo "Usage: $0 <primary_fqdn> <email> [additional_san_fqdn ...]" >&2
	exit 1
fi
PRIMARY="$1"
EMAIL="$2"
shift 2

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=le-acme-common.sh
. "$SCRIPT_DIR/le-acme-common.sh"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"

CERTBOT_D=( -d "$PRIMARY" )
for d in "$@"; do
	[ -n "$d" ] && CERTBOT_D+=( -d "$d" )
done

close_on_exit() {
	"$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

le_require_nginx_for_webroot
"$OPEN_SCRIPT"
# shellcheck disable=SC2046
certbot certonly $(le_certbot_auth_args) $(le_certbot_staging_args) "${CERTBOT_D[@]}" -m "$EMAIL" --agree-tos --non-interactive
mkdir -p "$(dirname "$LE_DOMAIN_FILE")"
echo "$PRIMARY" > "$LE_DOMAIN_FILE"
"$APPLY_SCRIPT"
