#!/bin/bash
# Re-apply home UFW baseline / allow-list after FQDN / sysglobal changes.
# Spec: UFW_SHOREWALL_MIGRATION.md (fqdninspect STRING retired).
set -e
SYSPATH="${SYSPATH:-/opt/pbx3}"
exec /usr/bin/php "$SYSPATH/php/utilities/firewall-reload.php"
