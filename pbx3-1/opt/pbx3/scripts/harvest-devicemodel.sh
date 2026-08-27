#!/bin/sh
# Soft-fill ipphone.devicevendor / devicemodel from AstDB registrar/contact.
# Disabled unless PBX3_HARVEST_DEVICEMODEL=1 (cron sets this when enabled).
# See EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md
set -eu

if [ "${PBX3_HARVEST_DEVICEMODEL:-0}" != "1" ]; then
	exit 0
fi

. /opt/pbx3/scripts/bashconfig
exec php "$UTILITIES/harvestDevicemodel.php"
