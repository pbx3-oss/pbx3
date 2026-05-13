#!/usr/bin/env bash
# Step 1 — pbx3 backend (multi-SAN first cert, NetHelper FQDN inline, update-fqdn-inline)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PBX3_ROOT="${PBX3_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SCRIPTS_PKG="$PBX3_ROOT/pbx3-1/opt/pbx3/scripts"
PBX3_OPT="${PBX3_OPT:-/opt/pbx3}"
SCRIPTS_OPT="$PBX3_OPT/scripts"
NETHELPER="$PBX3_ROOT/pbx3-1/opt/pbx3/php/classes/NetHelperClass"

echo "=== Step 1: pbx3 backend (scripts + firewall) ==="

need_script() {
	local name="$1"
	local hint="$2"
	if [[ -x "$SCRIPTS_PKG/$name" ]]; then
		tls_pass "repo script present + executable: $name"
	elif [[ -f "$SCRIPTS_PKG/$name" ]]; then
		tls_pass "repo script present: $name (not executable in tree — chmod on install)"
	else
		tls_fail "missing $SCRIPTS_PKG/$name ($hint)"
	fi
}

optional_opt_script() {
	local name="$1"
	if [[ -x "$SCRIPTS_OPT/$name" ]]; then
		tls_pass "on-box $SCRIPTS_OPT/$name exists"
	else
		tls_skip "no $SCRIPTS_OPT/$name (install package or run from dev tree only)"
	fi
}

need_script "le-first-cert.sh" "1.1 single-FQDN first issue"
need_script "le-renew-with-80.sh" "renewal with port 80"
need_script "apply-active-cert.sh" "apply active cert to nginx/Asterisk"

if [[ -f "$SCRIPTS_PKG/le-first-cert-multi.sh" ]]; then
	tls_pass "le-first-cert-multi.sh present (1.1 multi-SAN path)"
elif grep -qE "certbot certonly.*-d.*-d" "$SCRIPTS_PKG/le-first-cert.sh" 2>/dev/null; then
	tls_pass "le-first-cert.sh appears to support multiple -d (1.1)"
else
	tls_skip "multi-SAN first issue not implemented yet (1.1) — add le-first-cert-multi.sh or extend le-first-cert.sh"
fi

if [[ -f "$SCRIPTS_PKG/update-fqdn-inline.sh" ]]; then
	tls_pass "update-fqdn-inline.sh present (1.3)"
else
	tls_skip "update-fqdn-inline.sh not shipped yet (1.3)"
fi
optional_opt_script "update-fqdn-inline.sh"

if [[ -f "$NETHELPER" ]]; then
	if grep -qi "sip:" "$NETHELPER" && grep -q "copyFirewallTemplates" "$NETHELPER"; then
		tls_pass "NetHelperClass references sip: and copyFirewallTemplates (1.2 direction)"
	elif grep -q "copyFirewallTemplates" "$NETHELPER"; then
		tls_skip "NetHelperClass has copyFirewallTemplates but no sip: yet (1.2 partial)"
	else
		tls_fail "NetHelperClass missing expected FQDN-inline logic — implement 1.2"
	fi
else
	tls_fail "missing NetHelperClass at $NETHELPER"
fi

# 1.5 optional: Shorewall file on box
SHOREWALL_FQDN="${SHOREWALL_FQDN:-/etc/shorewall/pbx3_inline_fqdn}"
if [[ -r "$SHOREWALL_FQDN" ]]; then
	if grep -qE "INLINE.*sip:" "$SHOREWALL_FQDN" 2>/dev/null; then
		tls_pass "pbx3_inline_fqdn contains INLINE sip: rules (1.5)"
	else
		tls_skip "pbx3_inline_fqdn readable but no sip: INLINE lines yet (fqdninspect off or not regenerated)"
	fi
else
	tls_skip "no $SHOREWALL_FQDN on this host (1.5 on-PBX only)"
fi

exit "${TLS_TEST_FAILED:-0}"
