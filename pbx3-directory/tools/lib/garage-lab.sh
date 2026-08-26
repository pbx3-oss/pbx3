# shellcheck shell=bash
# Install and start a single-node Garage (Lab / T4 org store). Companion process — AGPL
# applies to Garage itself; product talks S3 API only (DESIGN_RULES Rule 9).
#
# Expects control-common.sh already sourced. Requires root.

GARAGE_VERSION="${GARAGE_VERSION:-v2.3.0}"
GARAGE_BIN="${GARAGE_BIN:-/usr/local/bin/garage}"
GARAGE_TOML="${GARAGE_TOML:-/etc/garage.toml}"
GARAGE_META_DIR="${GARAGE_META_DIR:-/var/lib/garage/meta}"
GARAGE_DATA_DIR="${GARAGE_DATA_DIR:-/var/lib/garage/data}"
GARAGE_DEFAULTS_ENV="${GARAGE_DEFAULTS_ENV:-/etc/pbx3-gatekeeper/garage-defaults.env}"
GARAGE_S3_BIND="${GARAGE_S3_BIND:-127.0.0.1:3900}"
GARAGE_WEB_BIND="${GARAGE_WEB_BIND:-127.0.0.1:3902}"
GARAGE_RPC_BIND="${GARAGE_RPC_BIND:-127.0.0.1:3901}"
GARAGE_ADMIN_BIND="${GARAGE_ADMIN_BIND:-127.0.0.1:3903}"
GARAGE_S3_REGION="${GARAGE_S3_REGION:-garage}"

garage_arch_triple() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64 | amd64) printf 'x86_64-unknown-linux-musl\n' ;;
    aarch64 | arm64) printf 'aarch64-unknown-linux-musl\n' ;;
    *)
      control_err "unsupported arch for Garage binary: $m (need amd64 or arm64)"
      return 1
      ;;
  esac
}

garage_download_url() {
  printf 'https://garagehq.deuxfleurs.fr/_releases/%s/%s/garage\n' \
    "$GARAGE_VERSION" "$(garage_arch_triple)"
}

garage_install_binary() {
  local url tmp
  if [[ -x "$GARAGE_BIN" ]] && "$GARAGE_BIN" --version 2>/dev/null | grep -q "${GARAGE_VERSION#v}"; then
    control_log "Garage ${GARAGE_VERSION} already installed at $GARAGE_BIN"
    return 0
  fi
  url="$(garage_download_url)"
  control_log "Downloading Garage ${GARAGE_VERSION} ($(uname -m))"
  tmp="$(mktemp)"
  if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$tmp"; then
    rm -f "$tmp"
    control_err "failed to download $url"
    return 1
  fi
  chmod 0755 "$tmp"
  mv "$tmp" "$GARAGE_BIN"
  control_log "Installed $GARAGE_BIN"
}

garage_ensure_user() {
  if ! id -u garage >/dev/null 2>&1; then
    useradd --system --home /var/lib/garage --shell /usr/sbin/nologin garage
  fi
  mkdir -p "$GARAGE_META_DIR" "$GARAGE_DATA_DIR"
  chown -R garage:garage /var/lib/garage
}

# Persist access keys (not rpc_secret). Tech never types these.
garage_write_defaults_env() {
  local access secret bucket
  bucket="$1"
  mkdir -p "$(dirname "$GARAGE_DEFAULTS_ENV")"
  if [[ -f "$GARAGE_DEFAULTS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$GARAGE_DEFAULTS_ENV"
    set +a
    if [[ -n "${GARAGE_DEFAULT_ACCESS_KEY:-}" && -n "${GARAGE_DEFAULT_SECRET_KEY:-}" ]]; then
      GARAGE_DEFAULT_BUCKET="${GARAGE_DEFAULT_BUCKET:-$bucket}"
      return 0
    fi
  fi
  access="GK$(control_rand_hex 16)"
  secret="$(control_rand_hex 32)"
  umask 077
  cat >"$GARAGE_DEFAULTS_ENV" <<EOF
GARAGE_DEFAULT_ACCESS_KEY=${access}
GARAGE_DEFAULT_SECRET_KEY=${secret}
GARAGE_DEFAULT_BUCKET=${bucket}
EOF
  chmod 0600 "$GARAGE_DEFAULTS_ENV"
  chown root:root "$GARAGE_DEFAULTS_ENV"
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$GARAGE_DEFAULTS_ENV"
  set +a
}

garage_write_toml() {
  local rpc_secret admin_token
  if [[ -f "$GARAGE_TOML" ]]; then
    control_log "Keeping existing $GARAGE_TOML"
    return 0
  fi
  rpc_secret="$(control_rand_hex 32)"
  admin_token="$(openssl rand -base64 32 | tr -d '\n')"
  umask 077
  cat >"$GARAGE_TOML" <<EOF
metadata_dir = "${GARAGE_META_DIR}"
data_dir = "${GARAGE_DATA_DIR}"
db_engine = "sqlite"
replication_factor = 1

rpc_bind_addr = "${GARAGE_RPC_BIND}"
rpc_public_addr = "${GARAGE_RPC_BIND}"
rpc_secret = "${rpc_secret}"

[s3_api]
s3_region = "${GARAGE_S3_REGION}"
api_bind_addr = "${GARAGE_S3_BIND}"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "${GARAGE_WEB_BIND}"
root_domain = ".web.garage.localhost"
index = "index.html"

[admin]
api_bind_addr = "${GARAGE_ADMIN_BIND}"
admin_token = "${admin_token}"
EOF
  chmod 0600 "$GARAGE_TOML"
  chown garage:garage "$GARAGE_TOML"
  control_log "Wrote $GARAGE_TOML"
}

garage_write_systemd() {
  cat >/etc/systemd/system/garage.service <<EOF
[Unit]
Description=Garage S3-compatible store (PBX3 Lab org bucket)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=garage
Group=garage
Environment=GARAGE_CONFIG_FILE=${GARAGE_TOML}
EnvironmentFile=-${GARAGE_DEFAULTS_ENV}
ExecStart=${GARAGE_BIN} server --single-node --default-bucket
Restart=on-failure
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now garage.service
}

garage_wait_ready() {
  local i
  for i in $(seq 1 40); do
    if "$GARAGE_BIN" -c "$GARAGE_TOML" status >/dev/null 2>&1; then
      control_log "Garage is up"
      return 0
    fi
    sleep 1
  done
  control_err "Garage did not become ready (see: journalctl -u garage)"
  return 1
}

# --default-bucket already created GARAGE_DEFAULT_BUCKET + default key.
# Enable website so nginx can GET catalog/* without signing.
garage_ensure_bucket() {
  local bucket="$1"
  if ! "$GARAGE_BIN" -c "$GARAGE_TOML" bucket info "$bucket" >/dev/null 2>&1; then
    "$GARAGE_BIN" -c "$GARAGE_TOML" bucket create "$bucket" >/dev/null
  fi
  "$GARAGE_BIN" -c "$GARAGE_TOML" bucket website --allow "$bucket" >/dev/null || true
}

# Dedicated recordings bucket — never website (private; homes PUT via presign).
garage_ensure_private_bucket() {
  local bucket="$1"
  if ! "$GARAGE_BIN" -c "$GARAGE_TOML" bucket info "$bucket" >/dev/null 2>&1; then
    "$GARAGE_BIN" -c "$GARAGE_TOML" bucket create "$bucket" >/dev/null
  fi
}

garage_bucket_allow_rw() {
  local bucket="$1" key="${2:-}"
  if [[ -z "$key" && -f "$GARAGE_DEFAULTS_ENV" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$GARAGE_DEFAULTS_ENV"
    set +a
    key="${GARAGE_DEFAULT_ACCESS_KEY:-}"
  fi
  if [[ -z "$key" ]]; then
    echo "garage_bucket_allow_rw: no access key" >&2
    return 1
  fi
  "$GARAGE_BIN" -c "$GARAGE_TOML" bucket allow "$bucket" --key "$key" --read --write >/dev/null
}

# Endpoint homes use in AWS_ENDPOINT / presigns. When bind is 0.0.0.0, pass LAN IP.
garage_s3_endpoint() {
  printf 'http://%s' "$GARAGE_S3_BIND"
}

garage_s3_client_endpoint() {
  local lan_ip="${1:-}"
  case "$GARAGE_S3_BIND" in
    0.0.0.0:*)
      if [[ -z "$lan_ip" ]]; then
        echo "garage_s3_client_endpoint: lan_ip required when bind is 0.0.0.0" >&2
        return 1
      fi
      printf 'http://%s:%s' "$lan_ip" "${GARAGE_S3_BIND##*:}"
      ;;
    *)
      garage_s3_endpoint
      ;;
  esac
}

garage_web_host() {
  local bucket="$1"
  printf '%s.web.garage.localhost' "$bucket"
}

# Full Lab Garage bring-up. Sets GARAGE_DEFAULT_* in the caller via defaults env.
garage_lab_install() {
  local bucket="$1"
  garage_install_binary
  garage_ensure_user
  garage_write_defaults_env "$bucket"
  garage_write_toml
  garage_write_systemd
  garage_wait_ready
  garage_ensure_bucket "$bucket"
}
