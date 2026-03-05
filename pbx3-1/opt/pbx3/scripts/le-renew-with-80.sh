#!/bin/bash
# Let's Encrypt renewal with port 80 under our control: open 80, run certbot renew, close 80.
# Used by POST /certificates/letsencrypt/renew and by scheduled renewal (cron/timer).
# Run as root. Requires certbot and apply-active-cert.sh.

set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
OPEN_SCRIPT="$SCRIPT_DIR/le-port80-open.sh"
CLOSE_SCRIPT="$SCRIPT_DIR/le-port80-close.sh"
DEPLOY_HOOK="$SCRIPT_DIR/apply-active-cert.sh"

# Always close port 80 on exit (success or failure)
close_on_exit() {
    "$CLOSE_SCRIPT" 2>/dev/null || true
}
trap close_on_exit EXIT

"$OPEN_SCRIPT"
certbot renew --quiet --deploy-hook "$DEPLOY_HOOK" 2>&1
