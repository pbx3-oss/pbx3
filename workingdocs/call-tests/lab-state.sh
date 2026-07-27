#!/usr/bin/env bash
# Toggle catcher-tenant lab state on golden for L1 pack scenarios.
# Usage: ./lab-state.sh <open|cfim|cfim-external|closed|master-closed|queue|multitenant|ensure-outroute|status>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./lab.env

: "${GOLDEN_SSH:?Set GOLDEN_SSH in lab.env (ssh … ubuntu@08jzwn.pbx3.com)}"
: "${CATCHER_USER:?}"
: "${CATCHER_EXT_A:=2000}"
: "${CATCHER_EXT_B:=2001}"
: "${CATCHER_QUEUE:=2060}"
: "${DID_CATCHER:?}"
# Off-box CFIM / outbound far-end (Magrathea DID → golden 1000, Ext alert)
: "${CFIM_EXTERNAL_DEST:=01924910444}"
: "${OUT_DIGITS:=01924910444}"

remote() {
  # shellcheck disable=SC2086
  $GOLDEN_SSH "$@"
}

ast() {
  remote "sudo asterisk -rx $(printf '%q' "$1")"
}

sql() {
  remote "sudo sqlite3 /opt/pbx3/db/sqlite.db $(printf '%q' "$1")"
}

set_openroute() {
  local dest="$1"
  sql "UPDATE inroutes SET openroute='$dest', z_updater='sipp-pack' WHERE pkey='$DID_CATCHER';"
}

clear_cfim() {
  ast "database del cfim $CATCHER_USER" >/dev/null || true
}

set_cfim() {
  local dest="$1"
  ast "database put cfim $CATCHER_USER $dest"
}

clear_tenant_closed() {
  local su="${CATCHER_DOMAIN%%.*}"
  ast "database del ${su} OCSTAT" >/dev/null || true
  ast "database del sipp OCSTAT" >/dev/null || true
}

set_tenant_closed() {
  local su="${CATCHER_DOMAIN%%.*}"
  ast "database put ${su} OCSTAT CLOSED"
}

clear_master_closed() {
  ast "database put STAT OCSTAT AUTO" >/dev/null || true
}

set_master_closed() {
  ast "database put STAT OCSTAT CLOSED"
}

ensure_outroute() {
  # Persist SIPP_MAIN in DB (survives GenAst Commit) + hot-add dialplan (until next reload).
  sql "INSERT INTO route (id,shortuid,pkey,active,alternate,auth,cluster,cname,description,dialplan,path1,path2,path3,path4,route,strategy,z_created,z_updated,z_updater)
SELECT 'sippMainOutRouteLab000000001','sippm1','SIPP_MAIN','YES','','NO','${CATCHER_DOMAIN%%.*}','','SIPp catcher MAIN→Egress','_XXXXX.','Egress','','','','SIPP_MAIN','hunt',datetime('now'),datetime('now'),'sipp-pack'
WHERE NOT EXISTS (SELECT 1 FROM route WHERE pkey='SIPP_MAIN');"
  ast "dialplan add extension _XXXXX.,1,agi(pbx3cagi,OutRoute,SIPP_MAIN,${CATCHER_DOMAIN%%.*},,,) into ${CATCHER_DOMAIN%%.*} replace"
  echo "lab-state: SIPP_MAIN _XXXXX. → Egress in ${CATCHER_DOMAIN%%.*}"
}

cmd="${1:-}"
case "$cmd" in
  open)
    clear_cfim
    clear_tenant_closed
    clear_master_closed
    set_openroute "$CATCHER_EXT_A"
    echo "lab-state: OPEN openroute=$CATCHER_EXT_A (no CFIM; master AUTO)"
    ;;
  cfim)
    clear_tenant_closed
    clear_master_closed
    set_openroute "$CATCHER_EXT_A"
    set_cfim "$CATCHER_EXT_B"
    echo "lab-state: CFIM $CATCHER_USER → $CATCHER_EXT_B"
    ;;
  cfim-external)
    clear_tenant_closed
    clear_master_closed
    set_openroute "$CATCHER_EXT_A"
    ensure_outroute
    set_cfim "$CFIM_EXTERNAL_DEST"
    echo "lab-state: CFIM-EXTERNAL $CATCHER_USER → $CFIM_EXTERNAL_DEST (via Egress)"
    ;;
  closed)
    clear_cfim
    clear_master_closed
    set_openroute "$CATCHER_EXT_A"
    set_tenant_closed
    echo "lab-state: CLOSED closeroute→$CATCHER_EXT_A"
    ;;
  master-closed)
    clear_cfim
    clear_tenant_closed
    set_openroute "$CATCHER_EXT_A"
    # closeroute already 2000 on catcher DID; master CLOSED forces it
    set_master_closed
    echo "lab-state: MASTER-CLOSED STAT/OCSTAT=CLOSED closeroute→$CATCHER_EXT_A"
    ;;
  queue)
    clear_cfim
    clear_tenant_closed
    clear_master_closed
    set_openroute "$CATCHER_QUEUE"
    echo "lab-state: QUEUE openroute=$CATCHER_QUEUE"
    ;;
  multitenant)
    : "${CATCHER_PEER_USER:?CATCHER_PEER_USER required for multitenant}"
    : "${CATCHER_PEER_DOMAIN:?}"
    echo "lab-state: MULTITENANT peer=${CATCHER_PEER_USER}@${CATCHER_PEER_DOMAIN} (usrloc contention); DID still → $CATCHER_EXT_A"
    ;;
  ensure-outroute)
    ensure_outroute
    ;;
  status)
    echo "--- inroute ---"
    sql "SELECT pkey,openroute,closeroute,cluster FROM inroutes WHERE pkey='$DID_CATCHER';"
    echo "--- cfim ---"
    ast "database get cfim $CATCHER_USER" || true
    echo "--- tenant OCSTAT ---"
    ast "database get ${CATCHER_DOMAIN%%.*} OCSTAT" || true
    echo "--- master STAT/OCSTAT ---"
    ast "database get STAT OCSTAT" || true
    echo "--- SIPP_MAIN route ---"
    sql "SELECT pkey,cluster,active,dialplan,path1 FROM route WHERE pkey='SIPP_MAIN';" || true
    if [[ -n "${CATCHER_PEER_USER:-}" ]]; then
      echo "--- peer phone ---"
      sql "SELECT pkey,shortuid,cluster,active FROM ipphone WHERE shortuid='${CATCHER_PEER_USER}';"
    fi
    ;;
  *)
    echo "Usage: $0 <open|cfim|cfim-external|closed|master-closed|queue|multitenant|ensure-outroute|status>" >&2
    exit 1
    ;;
esac
