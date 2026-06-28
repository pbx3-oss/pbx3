#!/bin/bash
# Re-issue Let's Encrypt certificate with the current SAN list (Option A sync, HTTP-01 webroot by default).
# Replaces the cert for --cert-name with exactly the FQDNs passed (adds and removes tenant names).
# Usage: le-sync-cert-sans.sh <email> <fqdn1> [<fqdn2> ...]
# fqdn1 must match /opt/pbx3/etc/identity/le-domain (certbot --cert-name).
# Run as root. Requires certbot, nginx ACME site, port 80 reachable.
# PBX3_LE_STAGING=1 or PBX3_LE_STANDALONE=1 — see le-acme-common.sh

set -e
if [ $# -lt 2 ]; then
	echo "Usage: $0 <email> <fqdn1> [<fqdn2> ...]" >&2
	exit 1
fi
EMAIL="$1"
shift

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=le-acme-common.sh
. "$SCRIPT_DIR/le-acme-common.sh"

if [ ! -f "$LE_DOMAIN_FILE" ]; then
	echo "No le-domain file at /opt/pbx3/etc/identity/le-domain" >&2
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

OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"

CERTBOT_D=()
for d in "$@"; do
	[ -n "$d" ] && CERTBOT_D+=( -d "$d" )
done

close_on_exit() {
	le_run_script "$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

le_require_nginx_for_webroot
le_run_script "$OPEN_SCRIPT"
# shellcheck disable=SC2046
# Do not use --expand: it only adds SANs. Sync must drop removed tenant FQDNs (backup restore, tenant delete).
certbot certonly $(le_certbot_auth_args) $(le_certbot_staging_args) --cert-name "$PRIMARY" "${CERTBOT_D[@]}" -m "$EMAIL" --agree-tos --non-interactive 2>&1
mkdir -p "$(dirname "$LE_DOMAIN_FILE")"
echo "$PRIMARY" > "$LE_DOMAIN_FILE"
le_run_script "$APPLY_SCRIPT"
