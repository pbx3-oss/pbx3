#!/usr/bin/env bash
# Offline checks for provision listener templates + UFW :41363 (A5).
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)" # …/opt/pbx3
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

HTTPS="$ROOT/etc/nginx/pbx3-provision-https.conf"
HTTP="$ROOT/etc/nginx/pbx3-provision-http.conf"
INSTALL="$ROOT/scripts/install-provision-listener.sh"
DEVICE="$ROOT/php/provisioning/device.php"

[[ -f "$HTTPS" ]] || fail "missing $HTTPS"
[[ -f "$HTTP" ]] || fail "missing $HTTP"
[[ -f "$INSTALL" ]] || fail "missing $INSTALL"
[[ -f "$DEVICE" ]] || fail "missing $DEVICE"

grep -q 'listen 41363 ssl' "$HTTPS" || fail "https conf missing listen 41363 ssl"
grep -q 'pbx3-ssl-active.conf' "$HTTPS" || fail "https conf missing ssl snippet"
grep -q 'device.php' "$HTTPS" || fail "https conf missing device.php"
ok "https template"

grep -q 'listen 41363;' "$HTTP" || fail "http conf missing plain listen 41363"
if grep -E 'listen[[:space:]].*ssl' "$HTTP" >/dev/null; then
  fail "http conf has ssl listen"
fi
grep -q 'device.php' "$HTTP" || fail "http conf missing device.php"
ok "http template"

# UFW bootstrap includes 41363
bash "$ROOT/scripts/tests/ufw-apply-baseline-test.sh" >/dev/null
ok "ufw baseline test (incl. 41363)"

echo "ALL PASSED"
