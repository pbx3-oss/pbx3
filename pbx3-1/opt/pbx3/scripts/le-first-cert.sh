#!/bin/bash
# First-time Let's Encrypt certificate (HTTP-01 webroot by default).
# Usage: le-first-cert.sh <fqdn> <email>
# Run as root. Requires certbot, nginx ACME site (pbx3-acme-http.conf), port 80 reachable.
# PBX3_LE_STAGING=1 or PBX3_LE_STANDALONE=1 — see le-acme-common.sh

set -e
if [ $# -lt 2 ]; then
    echo "Usage: $0 <fqdn> <email>" >&2
    exit 1
fi
FQDN="$1"
EMAIL="$2"
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=le-acme-common.sh
. "$SCRIPT_DIR/le-acme-common.sh"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
APPLY_SCRIPT="$SCRIPT_DIR/apply-active-cert.sh"

close_on_exit() {
    le_run_script "$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

le_require_nginx_for_webroot
le_run_script "$OPEN_SCRIPT"
# shellcheck disable=SC2046
certbot certonly $(le_certbot_auth_args) $(le_certbot_staging_args) -d "$FQDN" -m "$EMAIL" --agree-tos --non-interactive
mkdir -p "$(dirname "$LE_DOMAIN_FILE")"
echo "$FQDN" > "$LE_DOMAIN_FILE"
le_run_script "$APPLY_SCRIPT"
