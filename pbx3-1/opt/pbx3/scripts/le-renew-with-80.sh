#!/bin/bash
# Let's Encrypt renewal: open port 80 (Shorewall), certbot renew (webroot if cert was issued that way), close 80.
# Used by POST /certificates/letsencrypt/renew, /etc/cron.d/pbx3, and le-instance-bootstrap.sh.
# Run as root. Requires certbot and apply-active-cert.sh. nginx must serve ACME webroot for webroot renewals.

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=le-acme-common.sh
. "$SCRIPT_DIR/le-acme-common.sh"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
DEPLOY_HOOK="$SCRIPT_DIR/apply-active-cert.sh"

close_on_exit() {
	"$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

le_require_nginx_for_webroot
ensure_le_webroot
"$OPEN_SCRIPT"
certbot renew --quiet --deploy-hook "$DEPLOY_HOOK" 2>&1
