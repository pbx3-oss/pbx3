#!/usr/bin/env bash
# Prompted control-host installer (Lab T4 / D1).
#
# One SSH session on the control VM: Garage + org catalog + Gatekeeper + first fleet user.
# Keys stay on this box. Do not paste Garage/S3 secrets into Lab MkDocs.
#
# Usage:
#   sudo ./tools/install-control-host.sh
#   sudo PBX3_FLEET_SLUG=lab GATEKEEPER_ADMIN_EMAIL=you@example.com \
#        GATEKEEPER_ADMIN_PASSWORD='…' ./tools/install-control-host.sh
#
# Optional:
#   --in-place     use this checkout as /opt skip (dev)
#   --skip-apt     packages already installed
#   --skip-garage  S3 endpoint already in env (not Lab default)
#
# Spec: FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md § UX bar · Appendix B
# Harness: LAB_INSTALL_AUTOMATION_HARNESS.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/control-common.sh
source "$SCRIPT_DIR/lib/control-common.sh"
# shellcheck source=lib/garage-lab.sh
source "$SCRIPT_DIR/lib/garage-lab.sh"

INSTALL_DIR="${PBX3_GATEKEEPER_DIR:-/opt/pbx3-gatekeeper}"
ENV_DIR="/etc/pbx3-gatekeeper"
ENV_FILE="${ENV_DIR}/.env"
AUTH_DB="/var/lib/pbx3-gatekeeper/auth.sqlite"
GK_SRC="${DIR_ROOT}/gatekeeper"
NGINX_TMPL="${GK_SRC}/deploy/nginx-gatekeeper.conf.tmpl"
NGINX_SITE="/etc/nginx/sites-available/pbx3-gatekeeper"

IN_PLACE=0
SKIP_APT=0
SKIP_GARAGE=0
RECONFIGURE_NGINX=0

SLUG="${PBX3_FLEET_SLUG:-}"
CONTROL_IP="${PBX3_CONTROL_IP:-}"
SBC_ADMIN_API_URL="${PBX3_SBC_ADMIN_API_URL:-}"
ADMIN_EMAIL="${GATEKEEPER_ADMIN_EMAIL:-}"
ADMIN_PASSWORD="${GATEKEEPER_ADMIN_PASSWORD:-}"
ADMIN_NAME="${GATEKEEPER_ADMIN_NAME:-Fleet Admin}"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in-place) IN_PLACE=1; shift ;;
    --skip-apt) SKIP_APT=1; shift ;;
    --skip-garage) SKIP_GARAGE=1; shift ;;
    --reconfigure-nginx) RECONFIGURE_NGINX=1; shift ;;
    -h|--help) usage 0 ;;
    *)
      control_err "unknown arg: $1"
      usage 1
      ;;
  esac
done

control_require_root
control_require_cmd curl openssl

if [[ ! -f "${GK_SRC}/public/index.php" ]]; then
  control_err "gatekeeper tree not found at ${GK_SRC}"
  exit 1
fi

install_apt() {
  if [[ "$SKIP_APT" -eq 1 ]]; then
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    curl jq openssl unzip rsync nginx composer \
    php-cli php-fpm php-sqlite3 php-xml php-mbstring php-curl php-zip \
    >/dev/null
  local php_ver
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  systemctl enable --now "php${php_ver}-fpm" nginx >/dev/null 2>&1 || true
  control_log "apt packages ready"
}

# Ubuntu 24.04 has no awscli apt package. Official v2 bundle (arch-matched).
install_awscli_v2() {
  if command -v aws >/dev/null 2>&1; then
    control_log "aws CLI already present ($(aws --version 2>&1 | head -1))"
    return 0
  fi
  local arch zip url tmp
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) zip="awscli-exe-linux-x86_64.zip" ;;
    aarch64 | arm64) zip="awscli-exe-linux-aarch64.zip" ;;
    *)
      control_err "no AWS CLI v2 bundle for arch $arch"
      return 1
      ;;
  esac
  url="https://awscli.amazonaws.com/${zip}"
  tmp="$(mktemp -d)"
  control_log "Installing AWS CLI v2 ($arch)"
  curl -fsSL --retry 3 --retry-delay 2 "$url" -o "${tmp}/awscliv2.zip"
  unzip -q "${tmp}/awscliv2.zip" -d "$tmp"
  "${tmp}/aws/install"
  rm -rf "$tmp"
  command -v aws >/dev/null 2>&1 || {
    control_err "aws CLI v2 install finished but aws not on PATH"
    return 1
  }
  control_log "$(aws --version 2>&1 | head -1)"
}

php_fpm_socket() {
  local ver sock
  ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
  for sock in \
    "/run/php/php${ver}-fpm.sock" \
    "/var/run/php/php${ver}-fpm.sock" \
    "/run/php/php-fpm.sock"; do
    if [[ -S "$sock" ]]; then
      printf '%s' "$sock"
      return 0
    fi
  done
  printf '/run/php/php%s-fpm.sock' "$ver"
}

sync_gatekeeper_tree() {
  if [[ "$IN_PLACE" -eq 1 ]]; then
    INSTALL_DIR="$GK_SRC"
    control_log "In-place Gatekeeper at $INSTALL_DIR"
    return 0
  fi
  mkdir -p "$INSTALL_DIR"
  rsync -a \
    --exclude vendor --exclude .phpunit.cache --exclude data --exclude .env \
    "${GK_SRC}/" "${INSTALL_DIR}/"
  control_log "Synced Gatekeeper → $INSTALL_DIR"
}

composer_install() {
  export COMPOSER_ALLOW_SUPERUSER=1
  (
    cd "$INSTALL_DIR"
    composer install --no-dev --optimize-autoloader --no-interaction
  )
  mkdir -p "$(dirname "$AUTH_DB")" "${INSTALL_DIR}/data"
  chown -R www-data:www-data "$INSTALL_DIR" "$(dirname "$AUTH_DB")"
  control_log "composer install done"
}

write_gatekeeper_env() {
  local bucket="$1" endpoint="$2" catalog_url="$3"
  mkdir -p "$ENV_DIR"
  if [[ -f "$ENV_FILE" ]]; then
    control_log "Keeping existing $ENV_FILE (tokens not rotated)"
  else
    umask 077
    cat >"$ENV_FILE" <<EOF
PBX3_ORG_BUCKET=${bucket}
GATEKEEPER_API_TOKEN=$(control_rand_token)
AWS_DEFAULT_REGION=${GARAGE_S3_REGION}
AWS_ENDPOINT=${endpoint}
AWS_USE_PATH_STYLE_ENDPOINT=true
AWS_ACCESS_KEY_ID=${GARAGE_DEFAULT_ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${GARAGE_DEFAULT_SECRET_KEY}
PBX3_FLEET_SERVICE_TOKEN=$(control_rand_token)
PBX3_SBC_ADMIN_API_URL=${SBC_ADMIN_API_URL}
PBX3_FLEET_HTTP_VERIFY=false
GATEKEEPER_AUTH_DB=${AUTH_DB}
GATEKEEPER_FLEET_UI_URL=${catalog_url%catalog/*}
EOF
    control_log "Wrote $ENV_FILE"
  fi
  chmod 0640 "$ENV_FILE"
  chown root:www-data "$ENV_FILE"
  ln -sfn "$ENV_FILE" "${INSTALL_DIR}/.env"
  chown -h www-data:www-data "${INSTALL_DIR}/.env" || true
}

write_nginx() {
  local bind_name="$1" web_host="$2" sock php_ver
  sock="$(php_fpm_socket)"
  if [[ ! -f "$NGINX_TMPL" ]]; then
    control_err "missing $NGINX_TMPL"
    exit 1
  fi
  if [[ ! -f "${INSTALL_DIR}/public/index.php" ]]; then
    control_err "missing ${INSTALL_DIR}/public/index.php"
    exit 1
  fi
  sed \
    -e "s#__SERVER_NAME__#${bind_name}#g" \
    -e "s#__ROOT__#${INSTALL_DIR}#g" \
    -e "s#__PHP_FPM_SOCKET__#${sock}#g" \
    -e "s#__GARAGE_WEB_HOST__#${web_host}#g" \
    "$NGINX_TMPL" >"$NGINX_SITE"
  control_log "Wrote $NGINX_SITE (php-fpm ${sock})"
  ln -sfn "$NGINX_SITE" /etc/nginx/sites-enabled/pbx3-gatekeeper
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  systemctl restart "php${php_ver}-fpm" nginx
}

check_health() {
  local body code
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' http://127.0.0.1/health || true)"
  if [[ "$code" == "200" ]] && grep -q '"status"' "$body"; then
    control_log "GET /health ok"
    rm -f "$body"
    return 0
  fi
  control_err "GET /health failed (HTTP ${code:-none})"
  control_log "body: $(tr '\n' ' ' <"$body")"
  rm -f "$body"
  if [[ -f /var/log/nginx/error.log ]]; then
    control_log "nginx error.log (tail):"
    tail -n 15 /var/log/nginx/error.log >&2 || true
  fi
  return 1
}

bootstrap_catalog() {
  local slug="$1" catalog_url="$2"
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$GARAGE_DEFAULTS_ENV"
  set +a
  export AWS_ACCESS_KEY_ID="${GARAGE_DEFAULT_ACCESS_KEY}"
  export AWS_SECRET_ACCESS_KEY="${GARAGE_DEFAULT_SECRET_KEY}"
  export AWS_ENDPOINT
  AWS_ENDPOINT="$(garage_s3_endpoint)"
  export AWS_DEFAULT_REGION="${GARAGE_S3_REGION}"
  export AWS_USE_PATH_STYLE_ENDPOINT=true
  export AWS_EC2_METADATA_DISABLED=true
  "$SCRIPT_DIR/bootstrap-org-bucket.sh" --slug "$slug" --catalog-url "$catalog_url"
}

create_admin() {
  local out
  if [[ -z "$ADMIN_EMAIL" || -z "$ADMIN_PASSWORD" ]]; then
    control_err "admin email/password missing"
    return 1
  fi
    if (( ${#ADMIN_PASSWORD} < 10 )); then
    control_err "admin password must be at least 10 characters"
    return 1
  fi
  set +e
  out="$(
    sudo -u www-data php "${INSTALL_DIR}/bin/create-fleet-user.php" \
      --email "$ADMIN_EMAIL" \
      --password "$ADMIN_PASSWORD" \
      --name "$ADMIN_NAME" 2>&1
  )"
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    control_log "Fleet admin: $ADMIN_EMAIL"
    return 0
  fi
  if printf '%s' "$out" | grep -qiE 'unique|already|duplicate'; then
    control_log "Fleet admin already exists: $ADMIN_EMAIL"
    return 0
  fi
  printf '%s\n' "$out" >&2
  return "$rc"
}

# Lab units (cloud control still uses /home/ubuntu/gatekeeper + php8.4 in deploy/*.service).
install_fleet_probe() {
  local php_bin timer_src
  php_bin="$(command -v php || true)"
  if [[ -z "$php_bin" ]]; then
    control_err "php not on PATH — skip fleet probe timer"
    return 0
  fi
  if [[ ! -f "${INSTALL_DIR}/bin/probe-fleet-instances.php" ]]; then
    control_err "missing ${INSTALL_DIR}/bin/probe-fleet-instances.php — skip probe timer"
    return 0
  fi
  cat >/etc/systemd/system/pbx3-fleet-probe.service <<EOF
[Unit]
Description=PBX3 Gatekeeper fleet instance /up probe
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=www-data
Group=www-data
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=-/etc/pbx3-gatekeeper/.env
ExecStart=${php_bin} ${INSTALL_DIR}/bin/probe-fleet-instances.php
Nice=10
EOF
  timer_src="${INSTALL_DIR}/deploy/pbx3-fleet-probe.timer"
  if [[ ! -f "$timer_src" ]]; then
    timer_src="${GK_SRC}/deploy/pbx3-fleet-probe.timer"
  fi
  if [[ -f "$timer_src" ]]; then
    cp "$timer_src" /etc/systemd/system/pbx3-fleet-probe.timer
  else
    cat >/etc/systemd/system/pbx3-fleet-probe.timer <<'EOF'
[Unit]
Description=PBX3 Gatekeeper fleet instance probe every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=60s
AccuracySec=5s
Persistent=true
Unit=pbx3-fleet-probe.service

[Install]
WantedBy=timers.target
EOF
  fi
  systemctl daemon-reload
  systemctl enable --now pbx3-fleet-probe.timer
  systemctl start pbx3-fleet-probe.service || control_log "probe oneshot returned non-zero (will retry on timer)"
  control_log "fleet /up probe timer enabled (every 60s)"
}

print_banner() {
  local ip="$1" catalog_url="$2" fleet_tok="$3" sbc_url="$4"
  cat <<EOF

Control host ready (Lab). Next: browser, then the home VM installer
(sudo ./install-home-host.sh on the home box).

  Health:   http://${ip}/health
  Catalog:  ${catalog_url}
  Fleet:    SPA Fleet mode → http://${ip}
  Login:    ${ADMIN_EMAIL}

Copy for home / SBC installers (do not commit):
  PBX3_FLEET_SERVICE_TOKEN from ${ENV_FILE}
  PBX3_ORG_BUCKET=${BUCKET}
EOF
  if [[ -n "$sbc_url" ]]; then
    cat <<EOF
  PBX3_SBC_ADMIN_API_URL=${sbc_url}
EOF
  else
    cat <<EOF
  PBX3_SBC_ADMIN_API_URL=(unset — set after SBC admin install, then Provision edge)
EOF
  fi
  cat <<EOF

Garage keys stay in ${ENV_FILE}. Do not paste them into docs.

EOF
}

# --- prompts ---
control_prompt SLUG "Fleet slug (becomes {slug}-pbx3)" "lab"
BUCKET="$(control_org_bucket_from_slug "$SLUG")"
if [[ -z "$CONTROL_IP" ]]; then
  CONTROL_IP="$(control_detect_ipv4)"
fi
control_prompt CONTROL_IP "This VM LAN IP (browser will use it)" "${CONTROL_IP:-192.168.1.33}"
control_prompt ADMIN_EMAIL "Fleet admin email" "fleet@example.com"
control_prompt_secret ADMIN_PASSWORD "Fleet admin password (min 10 chars)"
control_prompt SBC_ADMIN_API_URL "SBC admin API URL (http://IP/api — Enter if no SIP yet)" ""

CATALOG_URL="http://${CONTROL_IP}/catalog/instance-index.json"

install_apt
install_awscli_v2

if [[ "$SKIP_GARAGE" -eq 1 ]]; then
  control_log "Skipping Garage (--skip-garage)"
  if [[ -z "${AWS_ENDPOINT:-}" || -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    control_err "--skip-garage needs AWS_ENDPOINT + static keys already set"
    exit 1
  fi
else
  garage_lab_install "$BUCKET"
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$GARAGE_DEFAULTS_ENV"
  set +a
fi

sync_gatekeeper_tree
composer_install
write_gatekeeper_env "$BUCKET" "$(garage_s3_endpoint)" "$CATALOG_URL"
if [[ -n "$SBC_ADMIN_API_URL" && -f "$ENV_FILE" ]]; then
  control_set_env_kv "$ENV_FILE" PBX3_SBC_ADMIN_API_URL "$SBC_ADMIN_API_URL"
  control_log "Set PBX3_SBC_ADMIN_API_URL in $ENV_FILE"
fi
bootstrap_catalog "$SLUG" "$CATALOG_URL"
write_nginx "_" "$(garage_web_host "$BUCKET")"
create_admin
install_fleet_probe

check_health

FLEET_TOKEN="$(grep '^PBX3_FLEET_SERVICE_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
SBC_URL="$(grep '^PBX3_SBC_ADMIN_API_URL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
print_banner "$CONTROL_IP" "$CATALOG_URL" "$FLEET_TOKEN" "$SBC_URL"
