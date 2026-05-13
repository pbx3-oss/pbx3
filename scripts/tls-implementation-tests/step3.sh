#!/usr/bin/env bash
# Step 3 — pbx3spa (tenant FQDN UI, Certificates panel)
if [ -z "${BASH_VERSION:-}" ]; then
	echo "This script requires bash, not sh/dash. Use: bash \"$0\"" >&2
	exit 1
fi
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PBX3_ROOT="${PBX3_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PBX3SPA_ROOT="${PBX3SPA_ROOT:-$PBX3_ROOT/../pbx3spa}"

echo "=== Step 3: pbx3spa (TLS UI) ==="

TV="$PBX3SPA_ROOT/src/views/TenantDetailView.vue"
CV="$PBX3SPA_ROOT/src/views/CertificatesView.vue"
CRV="$PBX3SPA_ROOT/src/views/TenantCreateView.vue"

if [[ -f "$TV" ]]; then
	if grep -qi "fqdn" "$TV"; then
		tls_pass "TenantDetailView references fqdn (3.1)"
	else
		tls_skip "TenantDetailView has no fqdn display yet (3.1)"
	fi
else
	tls_fail "missing TenantDetailView.vue"
fi

if [[ -f "$CRV" ]]; then
	if grep -qi "fqdn\|domain" "$CRV"; then
		tls_pass "TenantCreateView mentions fqdn/domain hint (3.2)"
	fi
else
	tls_skip "missing TenantCreateView.vue"
fi

if [[ -f "$CV" ]]; then
	if grep -qi "domains\|Cert covers\|letsencrypt/sync" "$CV"; then
		tls_pass "CertificatesView mentions domains list and/or sync (3.3)"
	else
		tls_skip "CertificatesView not yet showing domains / Sync (3.3)"
	fi
else
	tls_skip "no CertificatesView.vue yet — add when panel lands (3.3)"
fi

exit "${TLS_TEST_FAILED:-0}"
