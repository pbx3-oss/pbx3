#!/usr/bin/env bash
# Install control-host log retention (Phase 4) on control.pbx3.com
# Run as root from a pbx3-directory checkout (or copy deploy/ pieces).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root" >&2; exit 1; }

mkdir -p /etc/pbx3-gatekeeper /var/lib/pbx3-gatekeeper

install -m 644 "$ROOT/logrotate-pbx3-control-logs" /etc/logrotate.d/pbx3-control-logs
install -m 755 "$ROOT/ship-control-logs-to-s3.sh" /usr/local/bin/pbx3-control-ship-logs

# Prefer PHP shipper (Gatekeeper AWS SDK / instance role) — no aws CLI required
GATEKEEPER_ROOT="${GATEKEEPER_ROOT:-/home/ubuntu/gatekeeper}"
if [[ -f "$GATEKEEPER_ROOT/bin/ship-control-logs.php" ]]; then
  cat >/usr/local/bin/pbx3-control-ship-logs <<EOF
#!/bin/bash
exec /usr/bin/php8.4 ${GATEKEEPER_ROOT}/bin/ship-control-logs.php "\$@"
EOF
  chmod 755 /usr/local/bin/pbx3-control-ship-logs
  echo "Using PHP shipper at ${GATEKEEPER_ROOT}/bin/ship-control-logs.php"
elif [[ -f "$ROOT/../bin/ship-control-logs.php" ]]; then
  install -m 755 "$ROOT/../bin/ship-control-logs.php" "$GATEKEEPER_ROOT/bin/ship-control-logs.php" 2>/dev/null || true
fi

if [[ ! -f /etc/pbx3-gatekeeper/log-ship.env ]]; then
  install -m 640 "$ROOT/log-ship.env.example" /etc/pbx3-gatekeeper/log-ship.env
  # Prefer PBX3_ORG_BUCKET from gatekeeper .env if present
  if [[ -f /etc/pbx3-gatekeeper/.env ]]; then
    bucket=$(grep -E '^PBX3_ORG_BUCKET=' /etc/pbx3-gatekeeper/.env | head -1 | cut -d= -f2- || true)
    if [[ -n "$bucket" ]]; then
      sed -i "s/^PBX3_ORG_BUCKET=.*/PBX3_ORG_BUCKET=${bucket}/" /etc/pbx3-gatekeeper/log-ship.env
    fi
  fi
  echo "Created /etc/pbx3-gatekeeper/log-ship.env"
fi

cat >/etc/cron.d/pbx3-control-logs <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
45 6 * * * root /usr/local/bin/pbx3-control-ship-logs >> /var/log/pbx3-control-logs-s3.log 2>&1
EOF
chmod 644 /etc/cron.d/pbx3-control-logs

echo "Installed. Ensure IAM allows control/{id}/logs/* (update pbx3-control-gatekeeper-s3 policy)."
echo "Test: /usr/local/bin/pbx3-control-ship-logs --dry-run"
