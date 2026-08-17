#!/usr/bin/env bash
# Offline checks for control-host installer helpers (no Garage / no root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/control-common.sh
source "$SCRIPT_DIR/../lib/control-common.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok: $*"; }

got="$(control_org_bucket_from_slug lab)"
[[ "$got" == "lab-pbx3" ]] || fail "lab → $got"
pass "slug lab → lab-pbx3"

got="$(control_org_bucket_from_slug ACME)"
[[ "$got" == "acme-pbx3" ]] || fail "ACME → $got"
pass "slug ACME → acme-pbx3"

got="$(control_org_bucket_from_slug acme-pbx3)"
[[ "$got" == "acme-pbx3" ]] || fail "idempotent stem → $got"
pass "slug acme-pbx3 stays acme-pbx3"

if control_org_bucket_from_slug '.' >/dev/null 2>&1; then
  fail "expected reject for '.'"
fi
pass "rejects invalid slug"

json="$(control_empty_catalog_json lab)"
echo "$json" | jq -e '.version == 1 and (.instances | length) == 0' >/dev/null \
  || fail "empty catalog shape"
pass "empty catalog JSON"

echo "all helper tests passed"
