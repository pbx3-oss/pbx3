#!/bin/bash
# First Let's Encrypt certificate for this PBX instance (after DNS for globals.fqdn exists).
# Issues cert for node + all tenant cluster.fqdn values, writes le-domain, applies cert to nginx/Asterisk.
# Renewal is scheduled via /etc/cron.d/pbx3 (03:17 daily) when le-domain exists.
#
# Usage:
#   le-instance-bootstrap.sh <email>              # production LE
#   PBX3_LE_STAGING=1 le-instance-bootstrap.sh <email>
#
# Prerequisites: apt install pbx3 + pbx3api; installer.sh run; nginx with pbx3-acme-http.conf;
#   A/AAAA for globals.fqdn (and tenant FQDNs if multi-SAN); port 80 reachable from internet.

set -e

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root." >&2
	exit 1
fi
if [ $# -lt 1 ]; then
	echo "Usage: $0 <email>" >&2
	echo "Optional: PBX3_LE_STAGING=1 for Let's Encrypt staging." >&2
	exit 1
fi
EMAIL="$1"

SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
# shellcheck source=le-acme-common.sh
. "$SCRIPT_DIR/le-acme-common.sh"

if [ -f /opt/pbx3/scripts/bashconfig ]; then
	# shellcheck source=/dev/null
	. /opt/pbx3/scripts/bashconfig
else
	echo "ERROR: /opt/pbx3/scripts/bashconfig not found." >&2
	exit 1
fi

if [ ! -f "$SYSDB" ]; then
	echo "ERROR: database not found: $SYSDB (run installer.sh first)." >&2
	exit 1
fi

if [ -f "$LE_DOMAIN_FILE" ]; then
	_dom=$(tr -d '\n' < "$LE_DOMAIN_FILE")
	_fc="/etc/letsencrypt/live/${_dom}/fullchain.pem"
	if [ -n "$_dom" ] && [ -f "$_fc" ]; then
		echo "Let's Encrypt already configured (le-domain=$_dom). Use le-sync-cert-sans.sh or POST .../letsencrypt/sync to add tenant names." >&2
		exit 1
	fi
fi

PRIMARY=$(sqlite3 "$SYSDB" "SELECT trim(fqdn) FROM globals WHERE fqdn IS NOT NULL AND fqdn != '' LIMIT 1;" 2>/dev/null || true)
if [ -z "$PRIMARY" ]; then
	echo "ERROR: globals.fqdn is empty; run installer.sh and set instance FQDN first." >&2
	exit 1
fi

# Tenant FQDNs: default tenant first, then others (matches CertificateController::tenantFqdnSortedList).
mapfile -t _ALL_FQDNS < <(sqlite3 "$SYSDB" "
SELECT fqdn FROM cluster
WHERE fqdn IS NOT NULL AND trim(fqdn) != ''
ORDER BY CASE WHEN pkey = 'default' THEN 0 ELSE 1 END, pkey;
" 2>/dev/null)

SAN_ARGS=()
_seen=""
_add_san() {
	local f="$1"
	[ -z "$f" ] && return
	local k
	k=$(echo "$f" | tr '[:upper:]' '[:lower:]')
	case "$_seen" in *"|$k|"*) return ;; esac
	_seen="${_seen}|$k|"
	SAN_ARGS+=( "$f" )
}

_add_san "$PRIMARY"
for f in "${_ALL_FQDNS[@]}"; do
	_add_san "$(echo "$f" | tr -d '[:space:]')"
done

if [ "${#SAN_ARGS[@]}" -eq 0 ]; then
	echo "ERROR: no FQDNs to put on certificate." >&2
	exit 1
fi

echo "Instance FQDN (primary): $PRIMARY"
echo "Certificate will include ${#SAN_ARGS[@]} name(s):"
printf '  - %s\n' "${SAN_ARGS[@]}"

if command -v getent >/dev/null 2>&1; then
	_ips=$(getent ahosts "$PRIMARY" 2>/dev/null | awk '{print $1}' | sort -u | head -3)
	if [ -n "$_ips" ]; then
		echo "DNS resolves $PRIMARY to: $_ips"
	else
		echo "WARNING: could not resolve $PRIMARY locally; ensure public DNS is correct before continuing." >&2
	fi
fi

le_require_nginx_for_webroot
ensure_le_webroot

_extra=()
if [ "${#SAN_ARGS[@]}" -gt 1 ]; then
	_extra=( "${SAN_ARGS[@]:1}" )
fi

echo "Issuing certificate (webroot=${LE_WEBROOT})..."
le_run_script "$SCRIPT_DIR/le-first-cert-multi.sh" "$PRIMARY" "$EMAIL" "${_extra[@]}"

echo ""
echo "Done. Certificate files under /etc/letsencrypt/live/$(tr -d '\n' < "$LE_DOMAIN_FILE")/"
echo "Renewal: /etc/cron.d/pbx3 runs le-renew-with-80.sh daily at 03:17 when le-domain exists."
echo "After adding tenants: create DNS A records, then POST /api/certificates/letsencrypt/sync or le-sync-cert-sans.sh."
