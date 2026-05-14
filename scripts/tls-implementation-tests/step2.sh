#!/usr/bin/env bash
# Step 2 — pbx3api (certificates, firewall hooks, tenant/sysglobal side-effects)
if [ -z "${BASH_VERSION:-}" ]; then
	echo "This script requires bash, not sh/dash. Use: bash \"$0\"" >&2
	exit 1
fi
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PBX3_ROOT="${PBX3_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PBX3API_ROOT="$(tls_default_pbx3api_root "$PBX3_ROOT")"
PBX3API_BASE="${PBX3API_BASE:-}"
PBX3API_TOKEN="${PBX3API_TOKEN:-}"

echo "=== Step 2: pbx3api (TLS / certificates integration) ==="
echo "PBX3API_ROOT=$PBX3API_ROOT"

CC="$PBX3API_ROOT/app/Http/Controllers/CertificateController.php"
FW="$PBX3API_ROOT/app/Http/Controllers/FirewallController.php"
TC="$PBX3API_ROOT/app/Http/Controllers/TenantController.php"
SG="$PBX3API_ROOT/app/Http/Controllers/SysglobalController.php"
API_ROUTES="$PBX3API_ROOT/routes/api.php"

if [[ -f "$CC" ]]; then
	if grep -q "letsencrypt" "$CC" && grep -q "setup" "$CC"; then
		tls_pass "CertificateController has letsencrypt/setup"
	else
		tls_fail "CertificateController missing expected methods"
	fi
	if grep -qiE "sync|letsencrypt/sync" "$CC" && grep -q "letsencrypt/sync" "$API_ROUTES" 2>/dev/null; then
		tls_pass "POST certificates/letsencrypt/sync registered (2.4)"
	elif grep -qE "function sync|public function sync" "$CC"; then
		tls_pass "CertificateController sync method present"
	else
		tls_skip "POST /certificates/letsencrypt/sync not wired yet (2.4)"
	fi
	if grep -qi "domains" "$CC"; then
		tls_pass "CertificateController mentions domains[] / domains (2.3)"
	else
		tls_skip "GET letsencrypt domains[] not implemented yet (2.3)"
	fi
else
	tls_fail "missing CertificateController"
fi

if [[ -f "$FW" ]]; then
	if grep -qi "fqdn\|inline\|update-fqdn" "$FW"; then
		tls_pass "FirewallController mentions fqdn/inline/update (2.5 heuristic)"
	else
		tls_skip "FirewallController not yet calling update-fqdn-inline (2.5)"
	fi
else
	tls_skip "no FirewallController at $FW"
fi

if [[ -f "$TC" ]]; then
	if grep -q "shortuid" "$TC" && grep -q "globals" "$TC"; then
		tls_pass "TenantController still ties create to globals / shortuid (2.6 baseline)"
	fi
	if grep -q "pbx3_update_fqdn_inline_optional" "$TC"; then
		tls_pass "TenantController triggers update-fqdn-inline after tenant changes (2.6)"
	else
		tls_skip "TenantController missing pbx3_update_fqdn_inline_optional hook (2.6)"
	fi
else
	tls_fail "missing TenantController"
fi

if [[ -f "$SG" ]]; then
	if grep -q "fqdninspect" "$SG"; then
		tls_pass "SysglobalController handles fqdninspect (2.7 baseline)"
	fi
	if grep -q "pbx3_update_fqdn_inline_optional" "$SG"; then
		tls_pass "SysglobalController triggers update-fqdn-inline after fqdninspect/bindport (2.7)"
	else
		tls_skip "SysglobalController missing update-fqdn-inline hook (2.7)"
	fi
fi

if [[ -n "$PBX3API_BASE" && -n "$PBX3API_TOKEN" ]] && tls_need_cmd curl; then
	api="$PBX3API_BASE"
	[[ "$api" == */ ]] && api="${api%/}"
	ce="$api/api/certificates/letsencrypt"
	out=$(tls_curl_json "$ce" "$PBX3API_TOKEN" 2>/dev/null) || out=""
	if [[ -n "$out" ]]; then
		if tls_json_has_key "$out" domains; then
			tls_pass "GET certificates/letsencrypt includes domains (2.3 live)"
		else
			tls_skip "GET certificates/letsencrypt has no domains key yet"
		fi
	else
		tls_skip "GET certificates/letsencrypt failed (auth or not deployed)"
	fi
else
	tls_skip "PBX3API_BASE+PBX3API_TOKEN unset — skipping live certificate GET"
fi

exit "${TLS_TEST_FAILED:-0}"
