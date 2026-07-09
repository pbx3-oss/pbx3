#!/bin/bash
#
# Seed fleet Egress (+ optional EgressFailover) trunks on a PBX node instance DB.
# Phase A — FLEET_TRUNK_PEERING_DECISION.md §4.1
#
# Usage:
#   PBX3_SBC_EGRESS_HOST=sbc.pbx3.com ./seed-fleet-egress-trunk.sh [/opt/pbx3/db/sqlite.db]
#   PBX3_SBC_EGRESS_FAILOVER_HOST=sbc2.pbx3.com  # optional second trunk
#
set -euo pipefail

INSTANCE_DB="${1:-/opt/pbx3/db/sqlite.db}"
SBC_HOST="${PBX3_SBC_EGRESS_HOST:-sbc.pbx3.com}"
SBC_FAILOVER="${PBX3_SBC_EGRESS_FAILOVER_HOST:-}"

if [[ ! -f "$INSTANCE_DB" ]]; then
  echo "Error: instance database not found: $INSTANCE_DB" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 required" >&2
  exit 1
fi

seed_trunk() {
  local pkey=$1 host=$2
  local id shortuid
  id="$(openssl rand -hex 13)"
  shortuid="$(openssl rand -hex 4)"
  sqlite3 "$INSTANCE_DB" <<SQL
INSERT INTO trunks (
  id, shortuid, pkey, active, cluster, cname, description, host, technology, transport,
  peername, pjsipreg, callprogress, swoclip, z_created, z_updated, z_updater
) VALUES (
  '${id}', '${shortuid}', '${pkey}', 'YES', 'default', '${pkey}', 'Fleet SBC egress peer',
  '${host}', 'SIP', 'udp', '${pkey}', NULL, 'YES', 'YES', datetime('now'), datetime('now'), 'seed-fleet-egress'
)
ON CONFLICT(cluster, pkey) DO UPDATE SET
  active='YES', host='${host}', technology='SIP', transport='udp', peername='${pkey}',
  pjsipreg=NULL, z_updated=datetime('now'), z_updater='seed-fleet-egress';
SQL
  echo "OK: trunks.pkey=${pkey} → ${host}"
}

seed_trunk "Egress" "$SBC_HOST"
if [[ -n "$SBC_FAILOVER" ]]; then
  seed_trunk "EgressFailover" "$SBC_FAILOVER"
fi

# Fleet nodes: repoint legacy carrier route paths to Egress (pbx3cagi reads sqlite.rdonly.db)
sqlite3 "$INSTANCE_DB" <<'SQL'
UPDATE route SET path1='Egress', path2='None', path3='None', path4='None',
  z_updated=datetime('now'), z_updater='seed-fleet-egress'
WHERE path1 LIKE 'PDH%' OR path1 LIKE '%IAX%';
SQL

echo "Run: commit / regen Asterisk config on node after seeding."
