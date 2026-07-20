#!/usr/bin/env bash
# Lab deploy: ops-notify follow-ons (move-job mail + Fail2ban ban→email).
# Run from a Mac with working DNS/VPN (agent sandbox cannot reach lab hosts today).
# Does NOT wholesale git pull on the dirty live SBC tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PBX3_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"          # …/pbx3
MASTER="$(cd "$PBX3_ROOT/.." && pwd)"                 # …/pbx3-master (holding folder)
GK_SRC="$PBX3_ROOT/pbx3-directory/gatekeeper"
ADMIN_SRC="$MASTER/pbx3sbc-admin"

[[ -d "$GK_SRC" ]] || { echo "missing $GK_SRC" >&2; exit 1; }
[[ -d "$ADMIN_SRC" ]] || { echo "missing $ADMIN_SRC" >&2; exit 1; }

KEY_CTRL="${KEY_CTRL:-$HOME/Documents/pemfiles/pbx3test.pem}"
KEY_SBC="${KEY_SBC:-$HOME/Documents/pemfiles/opensips.pem}"
CTRL_HOST="${CTRL_HOST:-control.pbx3.com}"
SBC_HOST="${SBC_HOST:-sbc.pbx3.com}"
CTRL="ubuntu@${CTRL_HOST}"
SBC="ubuntu@${SBC_HOST}"

echo "== 1) Gatekeeper → ${CTRL_HOST} =="
rsync -az -e "ssh -i ${KEY_CTRL} -o BatchMode=yes" \
  --exclude .env --exclude vendor --exclude .phpunit.cache --exclude .git \
  "$GK_SRC/" "${CTRL}:/home/ubuntu/gatekeeper/"
ssh -i "$KEY_CTRL" -o BatchMode=yes "$CTRL" \
  'cd /home/ubuntu/gatekeeper && php8.4 "$(command -v composer)" install --no-dev -o && sudo systemctl reload php8.4-fpm'
ssh -i "$KEY_CTRL" -o BatchMode=yes "$CTRL" \
  'grep -c notifyMoveJobTerminal /home/ubuntu/gatekeeper/src/NotifyDispatcher.php; grep -c fail2ban_ban /home/ubuntu/gatekeeper/public/index.php; curl -sS https://control.pbx3.com/health; echo'

echo "== 2) Surgical SBC admin overlay → ${SBC_HOST} =="
ssh -i "$KEY_SBC" -o BatchMode=yes "$SBC" \
  'mkdir -p ~/pbx3sbc-admin/app/Services/Ops ~/pbx3sbc-admin/config ~/pbx3sbc-admin/deploy/cron.d ~/pbx3sbc-admin/tests/Unit'
scp -i "$KEY_SBC" -o BatchMode=yes \
  "$ADMIN_SRC/app/Services/Ops/Fail2banBanNotifyScanner.php" \
  "$ADMIN_SRC/app/Services/Ops/GatekeeperOpsClient.php" \
  "${SBC}:~/pbx3sbc-admin/app/Services/Ops/"
scp -i "$KEY_SBC" -o BatchMode=yes \
  "$ADMIN_SRC/config/pbx3_ops.php" \
  "${SBC}:~/pbx3sbc-admin/config/pbx3_ops.php"
scp -i "$KEY_SBC" -o BatchMode=yes \
  "$ADMIN_SRC/routes/console.php" \
  "${SBC}:~/pbx3sbc-admin/routes/console.php"
scp -i "$KEY_SBC" -o BatchMode=yes \
  "$ADMIN_SRC/deploy/cron.d/pbx3sbc-fail2ban-notify.example" \
  "${SBC}:~/pbx3sbc-admin/deploy/cron.d/pbx3sbc-fail2ban-notify.example"
scp -i "$KEY_SBC" -o BatchMode=yes \
  "$ADMIN_SRC/tests/Unit/Fail2banBanNotifyScannerTest.php" \
  "${SBC}:~/pbx3sbc-admin/tests/Unit/Fail2banBanNotifyScannerTest.php"

echo "== 3) Enable Fail2ban ban notify on SBC =="
TOKEN=$(ssh -i "$KEY_CTRL" -o BatchMode=yes "$CTRL" \
  "sudo grep -E '^GATEKEEPER_API_TOKEN=' /etc/pbx3-gatekeeper/.env | head -1 | cut -d= -f2-")
if [[ -z "${TOKEN}" ]]; then
  echo "Could not read GATEKEEPER_API_TOKEN from control" >&2
  exit 1
fi

# Pass token via env on remote without echoing it in process list longer than needed
ssh -i "$KEY_SBC" -o BatchMode=yes "$SBC" \
  "TOKEN=$(printf %q "$TOKEN") bash -s" <<'EOF'
set -euo pipefail
ENV=~/pbx3sbc-admin/.env
touch "$ENV"
for k in PBX3_OPS_FAIL2BAN_BAN_NOTIFY PBX3_GATEKEEPER_URL PBX3_GATEKEEPER_TOKEN PBX3_OPS_SBC_FQDN; do
  if grep -q "^${k}=" "$ENV" 2>/dev/null; then
    sed -i "/^${k}=/d" "$ENV"
  fi
done
{
  echo "PBX3_OPS_FAIL2BAN_BAN_NOTIFY=true"
  echo "PBX3_GATEKEEPER_URL=https://control.pbx3.com"
  echo "PBX3_GATEKEEPER_TOKEN=${TOKEN}"
  echo "PBX3_OPS_SBC_FQDN=sbc.pbx3.com"
} >> "$ENV"
cd ~/pbx3sbc-admin
php artisan config:clear
php artisan list --raw | grep -q ops-fail2ban-bans
php artisan pbx3sbc:ops-fail2ban-bans
sudo cp deploy/cron.d/pbx3sbc-fail2ban-notify.example /etc/cron.d/pbx3sbc-fail2ban-notify
sudo chmod 644 /etc/cron.d/pbx3sbc-fail2ban-notify
echo "SBC: cron installed; first artisan run should seed (no mail storm)"
EOF

echo "Done. Move-job mail is live with the gatekeeper rsync (notify_failures subscribers)."
