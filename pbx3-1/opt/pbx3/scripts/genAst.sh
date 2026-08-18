#!/bin/bash

. /opt/pbx3/scripts/bashconfig
[ ! -e $SYSDB ] && exit 4

# Phone outbound_proxy follows Egress host when env is unset (lab SPA Commit
# does not pass PBX3_SBC_EGRESS_HOST; default sbc.pbx3.com sends calls off-LAN).
if [ -z "${PBX3_SBC_EGRESS_HOST:-}" ] && command -v sqlite3 >/dev/null 2>&1; then
  _h="$(sqlite3 "$SYSDB" "SELECT host FROM trunks WHERE pkey='Egress' AND active='YES' LIMIT 1;" 2>/dev/null || true)"
  if [ -n "$_h" ]; then
    export PBX3_SBC_EGRESS_HOST="$_h"
  fi
fi

/usr/bin/logger Regenerating Asterisk

php $ASTGEN

# copy the DB
/bin/cp $SYSDB $COPY_DB
/bin/mv $COPY_DB $READONLY_DB
#
/usr/bin/logger Regenerating Asterisk Finished
#/usr/bin/sqlite3 $SYSDB "UPDATE globals SET mycommit='NO';"
