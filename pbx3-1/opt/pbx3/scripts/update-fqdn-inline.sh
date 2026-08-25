#!/bin/bash
# Apply home firewall after FQDN / sysglobal changes (NetHelper::restartFirewall).
# Under UFW: re-applies baseline (fqdninspect STRING retired). Under Shorewall: INLINE regen.
# Spec: UFW_SHOREWALL_MIGRATION.md F2 / Phase 2.
set -e
SYSPATH="${SYSPATH:-/opt/pbx3}"
exec /usr/bin/php "$SYSPATH/php/utilities/shorewallreload.php"
