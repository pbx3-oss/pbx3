#!/bin/bash
# Regenerate /etc/shorewall/pbx3_inline_fqdn (and pbx3_inline_limit) from SQLite via NetHelper,
# then run Shorewall check + restart. Option A / TLS_IMPLEMENTATION_STEPS.md Step 1.3.
# Run as root (same requirements as shorewallreload.php).
set -e
SYSPATH="${SYSPATH:-/opt/pbx3}"
exec /usr/bin/php "$SYSPATH/php/utilities/shorewallreload.php"
