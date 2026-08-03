#!/usr/bin/env bash
# Step 4 — integration / ops / docs (non-destructive checks)
if [ -z "${BASH_VERSION:-}" ]; then
	echo "This script requires bash, not sh/dash. Use: bash \"$0\"" >&2
	exit 1
fi
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PBX3_ROOT="${PBX3_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
SCRIPTS_PKG="$PBX3_ROOT/pbx3-1/opt/pbx3/scripts"
DOCS="$PBX3_ROOT/workingdocs"

echo "=== Step 4: integration & ops ==="

if grep -q "le-renew-with-80" "$SCRIPTS_PKG/le-renew-with-80.sh" 2>/dev/null; then
	tls_pass "le-renew-with-80.sh self-reference / present (4.1 baseline)"
fi
if grep -q "apply-active-cert" "$SCRIPTS_PKG/le-renew-with-80.sh" 2>/dev/null || \
   grep -q "apply-active-cert" "$SCRIPTS_PKG/apply-active-cert.sh" 2>/dev/null; then
	tls_pass "renew / apply scripts reference apply-active-cert (4.1)"
else
	tls_skip "could not grep apply-active-cert hook from renew script"
fi

if grep -q "ensure_le_tree_readable" "$SCRIPTS_PKG/apply-active-cert.sh" 2>/dev/null && \
   grep -q "ssl-cert" "$SCRIPTS_PKG/apply-active-cert.sh" 2>/dev/null && \
   grep -q "restart asterisk\|core restart" "$SCRIPTS_PKG/apply-active-cert.sh" 2>/dev/null; then
	tls_pass "apply-active-cert: LE ssl-cert ACLs + Asterisk restart for WSS :8089"
else
	tls_fail "apply-active-cert missing LE readability / asterisk restart (WSS bind)"
fi

if [[ -f "$DOCS/TLS_AND_CERTIFICATES.md" && -f "$DOCS/TLS_IMPLEMENTATION_STEPS.md" ]]; then
	tls_pass "TLS index + implementation steps docs present (4.4)"
else
	tls_fail "missing TLS workingdocs"
fi

if [[ -f "$DOCS/LETSENCRYPT_PER_TENANT_FQDN.md" ]] && grep -q "tenant move\|export\|import" "$DOCS/LETSENCRYPT_PER_TENANT_FQDN.md"; then
	tls_pass "LE doc mentions tenant mobility (4.2 runbook pointer)"
else
	tls_skip "tenant move wording not found in LE doc"
fi

if [[ -f "$DOCS/TODO.md" ]] && grep -q "44300\|TLS\|Sanctum" "$DOCS/TODO.md"; then
	tls_pass "TODO still tracks TLS finish pass (4.3 pointer)"
else
	tls_skip "TODO.md has no obvious 44300/TLS line"
fi

# Optional: system crontab on PBX (read-only)
if tls_need_cmd crontab && [[ "${TLS_CHECK_USER_CRONTAB:-}" == "1" ]]; then
	if crontab -l 2>/dev/null | grep -q "le-renew\|certbot"; then
		tls_pass "user crontab references certbot/le-renew"
	else
		tls_skip "no certbot/le-renew in this user's crontab (try root or TLS_CHECK_USER_CRONTAB=0)"
	fi
else
	tls_skip "set TLS_CHECK_USER_CRONTAB=1 to inspect crontab for 4.1"
fi

exit "${TLS_TEST_FAILED:-0}"
