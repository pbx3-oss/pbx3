#!/usr/bin/env bash
# Toggle catcher-tenant lab state on golden for L1 pack scenarios.
# Usage: ./lab-state.sh <open|cfim|closed|queue|multitenant|status>
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

clear_closed() {
  # Tenant AstDB override (cluster shortuid from FQDN label)
  local su="${CATCHER_DOMAIN%%.*}"
  ast "database del ${su} OCSTAT" >/dev/null || true
  ast "database del sipp OCSTAT" >/dev/null || true
}

set_closed() {
  local su="${CATCHER_DOMAIN%%.*}"
  ast "database put ${su} OCSTAT CLOSED"
}

cmd="${1:-}"
case "$cmd" in
  open)
    clear_cfim
    clear_closed
    set_openroute "$CATCHER_EXT_A"
    echo "lab-state: OPEN openroute=$CATCHER_EXT_A (no CFIM)"
    ;;
  cfim)
    clear_closed
    set_openroute "$CATCHER_EXT_A"
    set_cfim "$CATCHER_EXT_B"
    echo "lab-state: CFIM $CATCHER_USER → $CATCHER_EXT_B"
    ;;
  closed)
    clear_cfim
    set_openroute "$CATCHER_EXT_A"
    set_closed
    echo "lab-state: CLOSED closeroute→$CATCHER_EXT_A"
    ;;
  queue)
    clear_cfim
    clear_closed
    set_openroute "$CATCHER_QUEUE"
    echo "lab-state: QUEUE openroute=$CATCHER_QUEUE"
    ;;
  multitenant)
    # Preconditions only — peer REGISTER is started by run-pack.
    : "${CATCHER_PEER_USER:?CATCHER_PEER_USER required for multitenant}"
    : "${CATCHER_PEER_DOMAIN:?}"
    echo "lab-state: MULTITENANT peer=${CATCHER_PEER_USER}@${CATCHER_PEER_DOMAIN} (usrloc contention); DID still → $CATCHER_EXT_A"
    ;;
  status)
    echo "--- inroute ---"
    sql "SELECT pkey,openroute,closeroute,cluster FROM inroutes WHERE pkey='$DID_CATCHER';"
    echo "--- cfim ---"
    ast "database get cfim $CATCHER_USER" || true
    echo "--- OCSTAT ---"
    ast "database get ${CATCHER_DOMAIN%%.*} OCSTAT" || true
    if [[ -n "${CATCHER_PEER_USER:-}" ]]; then
      echo "--- peer phone ---"
      sql "SELECT pkey,shortuid,cluster,active FROM ipphone WHERE shortuid='${CATCHER_PEER_USER}';"
    fi
    ;;
  *)
    echo "Usage: $0 <open|cfim|closed|queue|multitenant|status>" >&2
    exit 1
    ;;
esac
