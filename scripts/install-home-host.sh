#!/usr/bin/env bash
# Prompted Lab home installer (T4 / D1).
#
# One SSH session on the home VM: pbx3 .deb + pbx3api, skip CAGI on ARM, skip Let's Encrypt.
#
# Copy next to this script (or set env):
#   pbx3_*.deb
#   pbx3api/   (git tree)
#
# Usage:
#   sudo ./install-home-host.sh
#   sudo DOMAIN_TLD=pbx3.com INSTANCE_SITENAME='Lab Home' \
#        PBX3_ADMIN_EMAIL=you@example.com PBX3_ADMIN_PASSWORD='…' \
#        PBX3_FLEET_SERVICE_TOKEN='…' PBX3_ORG_BUCKET=lab-pbx3 \
#        PBX3_SBC_EGRESS_HOST=192.168.1.85 \
#        PBX3_CLEAN_INSTALL=1 \
#        ./install-home-host.sh
#
# Spec: FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md § UX bar
# Harness: LAB_INSTALL_AUTOMATION_HARNESS.md
# MkDocs: installation/install-lab-home.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

home_log() { printf 'home: %s\n' "$*"; }
home_err() { printf 'home: ERROR: %s\n' "$*" >&2; }

DOMAIN_TLD="${DOMAIN_TLD:-}"
INSTANCE_SITENAME="${INSTANCE_SITENAME:-}"
PBX3_ADMIN_EMAIL="${PBX3_ADMIN_EMAIL:-}"
PBX3_ADMIN_PASSWORD="${PBX3_ADMIN_PASSWORD:-}"
PBX3_DEB="${PBX3_DEB:-}"
PBX3API_SRC="${PBX3API_SRC:-}"
INSTALL_CAGI="${PBX3_INSTALL_CAGI:-0}"
PBX3_FLEET_SERVICE_TOKEN="${PBX3_FLEET_SERVICE_TOKEN:-}"
PBX3_ORG_BUCKET="${PBX3_ORG_BUCKET:-}"
PBX3_SKIP_FLEET="${PBX3_SKIP_FLEET:-0}"
PBX3_SBC_EGRESS_HOST="${PBX3_SBC_EGRESS_HOST:-}"
SEED_EGRESS_SCRIPT="${SEED_EGRESS_SCRIPT:-}"
PBX3_CLEAN_INSTALL="${PBX3_CLEAN_INSTALL:-0}"
FLEET_CONFIGURED=0

if [[ "$(id -u)" -ne 0 ]]; then
  home_err "run as root (sudo $0)"
  exit 1
fi

home_prompt() {
  local var="$1" question="$2" default="${3:-}"
  local cur ans
  cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ -t 0 ]]; then
    if [[ -n "$default" ]]; then
      read -r -p "$question [$default]: " ans || true
    else
      read -r -p "$question: " ans || true
    fi
    ans="${ans:-$default}"
    printf -v "$var" '%s' "$ans"
    return 0
  fi
  if [[ -n "$default" ]]; then
    printf -v "$var" '%s' "$default"
    return 0
  fi
  home_err "non-interactive: set $var"
  return 1
}

home_prompt_secret() {
  local var="$1" question="$2"
  local cur ans confirm attempts=0
  cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    home_err "non-interactive: set $var"
    return 1
  fi
  while (( attempts < 3 )); do
    read -r -s -p "$question: " ans || true
    echo
    if [[ -z "$ans" ]]; then
      home_err "password cannot be empty"
      return 1
    fi
    read -r -s -p "Confirm password: " confirm || true
    echo
    if [[ "$ans" == "$confirm" ]]; then
      printf -v "$var" '%s' "$ans"
      return 0
    fi
    attempts=$((attempts + 1))
    echo "Passwords do not match. Try again." >&2
  done
  home_err "password confirmation failed"
  return 1
}

find_deb() {
  local f best="" bestver="" ver
  if [[ -n "$PBX3_DEB" && -f "$PBX3_DEB" ]]; then
    printf '%s' "$PBX3_DEB"
    return 0
  fi
  shopt -s nullglob
  for f in "${SCRIPT_DIR}"/pbx3_*.deb /tmp/pbx3_*.deb "${PWD}"/pbx3_*.deb; do
    [[ -f "$f" ]] || continue
    ver="$(basename "$f")"
    ver="${ver#pbx3_}"
    ver="${ver%_all.deb}"
    ver="${ver%.deb}"
    if [[ -z "$best" ]] || dpkg --compare-versions "$ver" gt "$bestver"; then
      best="$f"
      bestver="$ver"
    fi
  done
  shopt -u nullglob
  if [[ -z "$best" ]]; then
    return 1
  fi
  printf '%s' "$best"
}

deb_version() {
  local base ver
  base="$(basename "$1")"
  ver="${base#pbx3_}"
  ver="${ver%_all.deb}"
  printf '%s' "${ver%.deb}"
}

overlay_floor_installer() {
  local src s
  for s in installer.sh link-asterisk-configs.sh seed-fleet-egress-trunk.sh; do
    if [[ -f "${SCRIPT_DIR}/../pbx3-1/opt/pbx3/scripts/${s}" ]]; then
      src="${SCRIPT_DIR}/../pbx3-1/opt/pbx3/scripts/${s}"
    elif [[ -f "${SCRIPT_DIR}/${s}" ]]; then
      src="${SCRIPT_DIR}/${s}"
    else
      continue
    fi
    cp -a "$src" "/opt/pbx3/scripts/${s}"
    chmod 755 "/opt/pbx3/scripts/${s}"
    home_log "Overlaid ${s} → /opt/pbx3/scripts/"
  done
  if [[ -f "${SCRIPT_DIR}/../pbx3-1/opt/pbx3/scripts/installer.sh" ]]; then
    home_log "Installer: FQDN minted {shortuid}.{apex}; not prompted"
  fi
  if grep -q 'node1.pbx3.com' /opt/pbx3/scripts/installer.sh 2>/dev/null; then
    home_err "installer.sh still asks for Instance FQDN (node1.pbx3.com). Install floor pbx3_0.0.5-5 or newer, or overlay from pbx3-1."
    return 1
  fi
}

find_api_src() {
  if [[ -n "$PBX3API_SRC" && -f "${PBX3API_SRC}/scripts/installer.sh" ]]; then
    printf '%s' "$PBX3API_SRC"
    return 0
  fi
  local d
  for d in \
    "${SCRIPT_DIR}/pbx3api" \
    /tmp/pbx3api \
    "${PWD}/pbx3api" \
    /opt/pbx3api; do
    if [[ -f "${d}/scripts/installer.sh" ]]; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
}

home_set_env_kv() {
  local file="$1" key="$2" val="$3"
  touch "$file"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    # Ensure append starts on its own line (.env.example may lack a trailing newline).
    if [[ -s "$file" ]]; then
      local lastbyte
      lastbyte="$(tail -c 1 "$file" 2>/dev/null || true)"
      if [[ -n "$lastbyte" && "$lastbyte" != $'\n' ]]; then
        printf '\n' >>"$file"
      fi
    fi
    echo "${key}=${val}" >>"$file"
  fi
}

find_seed_egress_script() {
  local f
  if [[ -n "$SEED_EGRESS_SCRIPT" && -f "$SEED_EGRESS_SCRIPT" ]]; then
    printf '%s' "$SEED_EGRESS_SCRIPT"
    return 0
  fi
  for f in \
    "${SCRIPT_DIR}/seed-fleet-egress-trunk.sh" \
    /opt/pbx3/scripts/seed-fleet-egress-trunk.sh \
    "${SCRIPT_DIR}/../pbx3-directory/tools/seed-fleet-egress-trunk.sh" \
    /tmp/seed-fleet-egress-trunk.sh; do
    if [[ -f "$f" ]]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

home_configure_fleet_api() {
  local env_file="/opt/pbx3api/.env"
  local bucket_default="${PBX3_ORG_BUCKET:-}"

  if [[ "$PBX3_SKIP_FLEET" == "1" ]]; then
    home_log "Skipping fleet API env (PBX3_SKIP_FLEET=1)"
    return 0
  fi

  if [[ -z "$PBX3_FLEET_SERVICE_TOKEN" && -t 0 ]]; then
    read -r -p "Fleet service token (same value as control/SBC — Enter to skip fleet): " PBX3_FLEET_SERVICE_TOKEN || true
  fi
  if [[ -z "$PBX3_FLEET_SERVICE_TOKEN" ]]; then
    home_log "Skipping fleet API env (no PBX3_FLEET_SERVICE_TOKEN)"
    return 0
  fi

  if [[ -z "$PBX3_SBC_EGRESS_HOST" ]]; then
    home_prompt PBX3_SBC_EGRESS_HOST "SBC egress host/IP (required for fleet lab)" ""
  fi
  if [[ -z "$PBX3_SBC_EGRESS_HOST" ]]; then
    home_err "PBX3_SBC_EGRESS_HOST required when PBX3_FLEET_SERVICE_TOKEN is set"
    exit 1
  fi

  if [[ -z "$bucket_default" ]]; then
    home_prompt PBX3_ORG_BUCKET "Org bucket (same as control host)" "lab-pbx3"
    bucket_default="$PBX3_ORG_BUCKET"
  fi

  home_log "Writing fleet API settings to $env_file"
  home_set_env_kv "$env_file" PBX3_FLEET_MODE true
  home_set_env_kv "$env_file" PBX3_FLEET_SERVICE_TOKEN "$PBX3_FLEET_SERVICE_TOKEN"
  home_set_env_kv "$env_file" PBX3_ORG_BUCKET "$bucket_default"
  home_set_env_kv "$env_file" PBX3_DIRECTORY_BACKUP_UPLOAD true
  home_set_env_kv "$env_file" PBX3_SBC_EGRESS_HOST "$PBX3_SBC_EGRESS_HOST"
  (cd /opt/pbx3api && php artisan config:clear) || true
  FLEET_CONFIGURED=1
}

home_link_asterisk_configs() {
  if [[ -x /opt/pbx3/scripts/link-asterisk-configs.sh ]]; then
    home_log "Linking /etc/asterisk → GenAst configs (stubs + runLinker)"
    /opt/pbx3/scripts/link-asterisk-configs.sh
  elif command -v php >/dev/null 2>&1 && [[ -f /opt/pbx3/php/utilities/runLinker.php ]]; then
    home_log "Linking /etc/asterisk (legacy runLinker only)"
    php /opt/pbx3/php/utilities/runLinker.php >/dev/null
  fi
}

home_seed_fleet_egress() {
  local seed sbc_host="${PBX3_SBC_EGRESS_HOST:-}"

  if [[ "$FLEET_CONFIGURED" -ne 1 ]]; then
    if [[ -z "$sbc_host" ]]; then
      return 0
    fi
  fi

  if [[ -z "$sbc_host" ]]; then
    home_err "PBX3_SBC_EGRESS_HOST required for fleet install"
    exit 1
  fi

  PBX3_SBC_EGRESS_HOST="$sbc_host"
  home_set_env_kv "/opt/pbx3api/.env" PBX3_SBC_EGRESS_HOST "$sbc_host"

  if ! seed="$(find_seed_egress_script)"; then
    home_err "seed-fleet-egress-trunk.sh not found (expected pbx3/scripts/ or /opt/pbx3/scripts/)"
    exit 1
  fi
  home_log "Seeding Egress trunk → ${sbc_host} ($seed)"
  PBX3_SBC_EGRESS_HOST="$sbc_host" bash "$seed" /opt/pbx3/db/sqlite.db
  /opt/pbx3/scripts/genAst.sh
  home_link_asterisk_configs
  systemctl restart asterisk
  home_log "Egress trunk seeded; Asterisk restarted"
}

home_verify_fleet_install() {
  [[ "$FLEET_CONFIGURED" -eq 1 ]] || return 0

  local fail=0 row active host
  home_log "Verifying fleet install (posture + Egress + Asterisk symlinks)..."

  if ! grep -qE '^PBX3_FLEET_MODE=(true|1|yes)' /opt/pbx3api/.env 2>/dev/null; then
    home_err "PBX3_FLEET_MODE not set correctly in /opt/pbx3api/.env"
    fail=1
  fi
  if ! grep -qE '^PBX3_SBC_EGRESS_HOST=' /opt/pbx3api/.env 2>/dev/null; then
    home_err "PBX3_SBC_EGRESS_HOST missing in /opt/pbx3api/.env"
    fail=1
  fi

  row="$(sqlite3 /opt/pbx3/db/sqlite.db "SELECT active, host FROM trunks WHERE pkey='Egress' LIMIT 1;" 2>/dev/null || true)"
  active="${row%%|*}"
  host="${row#*|}"
  if [[ "$active" != "YES" || -z "$host" ]]; then
    home_err "Egress trunk missing or inactive in sqlite (got: ${row:-none})"
    fail=1
  fi

  local f
  for f in pjsip_ready_trunks.conf pjsip_ready_phones.conf pjsip_ready_webrtc.conf; do
    if [[ ! -L "/etc/asterisk/$f" ]]; then
      home_err "missing symlink /etc/asterisk/$f (run link-asterisk-configs.sh)"
      fail=1
    fi
  done

  if [[ "$fail" -ne 0 ]]; then
    home_err "Fleet install verification failed — fix above before adopt/phones"
    exit 1
  fi
  home_log "Fleet install verification OK (Egress → ${host})"
}

arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
if [[ "$arch" != "amd64" ]]; then
  INSTALL_CAGI=0
fi

home_prompt DOMAIN_TLD "Domain apex — press Enter for pbx3.com" "pbx3.com"
home_prompt INSTANCE_SITENAME "Site name (friendly Name)" "Lab Home"
home_prompt PBX3_ADMIN_EMAIL "Admin SPA email (not a docs placeholder)"
home_prompt_secret PBX3_ADMIN_PASSWORD "Admin SPA password (min 8 chars)"

if [[ ${#PBX3_ADMIN_PASSWORD} -lt 8 ]]; then
  home_err "admin password must be at least 8 characters"
  exit 1
fi

deb=""
if ! deb="$(find_deb)"; then
  home_err "pbx3_*.deb not found (set PBX3_DEB or copy next to this script / into /tmp)"
  exit 1
fi
debver="$(deb_version "$deb")"
inst=""
if dpkg-query -W pbx3 >/dev/null 2>&1; then
  inst="$(dpkg-query -W -f '${Version}' pbx3)"
fi
if [[ -z "$inst" ]] || dpkg --compare-versions "$inst" lt "$debver"; then
  home_log "Installing $deb (have ${inst:-none}, want $debver)"
  export DEBIAN_FRONTEND=noninteractive
  echo 'slapd slapd/no_configuration boolean true' | debconf-set-selections
  apt-get update -qq
  apt-get install -y ssmtp sqlite3 curl ca-certificates git
  chmod +x /etc/ssmtp 2>/dev/null || true
  apt-get install -y "$deb"
else
  home_log "pbx3 already $inst (>= $debver)"
fi
overlay_floor_installer || exit 1

if [[ "$INSTALL_CAGI" == "1" ]]; then
  home_log "CAGI requested — install pbx3cagi_*.deb yourself (not this Lab default)"
else
  home_log "Skipping CAGI (Lab / arch=${arch})"
fi

export DOMAIN_TLD INSTANCE_SITENAME PBX3_ADMIN_EMAIL PBX3_ADMIN_PASSWORD
if [[ "$PBX3_CLEAN_INSTALL" == "1" && -f /opt/pbx3/db/sqlite.db ]]; then
  home_log "PBX3_CLEAN_INSTALL=1 — removing existing sqlite.db for fresh provision"
  systemctl stop asterisk 2>/dev/null || true
  rm -f /opt/pbx3/db/sqlite.db /opt/pbx3/db/sqlite.rdonly.db /opt/pbx3/db/sqlite.copy.db
fi
home_log "Running pbx3 installer.sh (mints FQDN={shortuid}.${DOMAIN_TLD}; does not ask for FQDN)"
if [[ -f /opt/pbx3/db/sqlite.db ]]; then
  _oldfq="$(sqlite3 /opt/pbx3/db/sqlite.db "SELECT fqdn FROM globals LIMIT 1;" 2>/dev/null || true)"
  _oldlab="${_oldfq%%.*}"
  if [[ -n "$_oldfq" && ! "$_oldlab" =~ ^[0-9bcdfghjkmnpqrstvwxyz]{6}$ ]]; then
    home_err "existing globals.fqdn=${_oldfq} is not {shortuid}.{apex}. Remove /opt/pbx3/db/sqlite.db and re-run (do not type node1.pbx3.com)."
    exit 1
  fi
fi
/opt/pbx3/scripts/installer.sh

# Floor deb 0.0.5-5 calls bootstrap with /bin/sh; git tip uses bash.
if [[ -x /opt/pbx3/scripts/bootstrap-admin-user.sh ]]; then
  /bin/bash /opt/pbx3/scripts/bootstrap-admin-user.sh /opt/pbx3/db/sqlite.db || true
fi
ucount="$(sqlite3 /opt/pbx3/db/sqlite.db 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo 0)"
if [[ "${ucount:-0}" -lt 1 ]]; then
  home_err "no SPA admin in users — bootstrap failed"
  exit 1
fi

api_src=""
if ! api_src="$(find_api_src)"; then
  home_err "pbx3api tree not found (set PBX3API_SRC or copy to /tmp/pbx3api)"
  exit 1
fi
if [[ "$api_src" != "/opt/pbx3api" ]]; then
  home_log "Installing pbx3api from $api_src"
  rm -rf /opt/pbx3api
  mkdir -p /opt/pbx3api
  # Keep vendor if the copy already has it; installer runs composer if not.
  rsync -a --exclude .git --exclude node_modules "${api_src}/" /opt/pbx3api/
fi
rm -f /etc/nginx/sites-enabled/default
home_log "Running pbx3api installer.sh (snakeoil :44300, no Let's Encrypt)"
/opt/pbx3api/scripts/installer.sh

home_configure_fleet_api
home_seed_fleet_egress
home_link_asterisk_configs
home_verify_fleet_install

ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
ip="${ip:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
ident="$(sqlite3 /opt/pbx3/db/sqlite.db "SELECT id, shortuid, fqdn, sitename FROM globals WHERE pkey='global';" 2>/dev/null || true)"

cat <<EOF

Home PBX ready (Lab). No Let's Encrypt; API is snakeoil on :44300.

  Identity: ${ident}
  Health:   https://${ip:-127.0.0.1}:44300/up   (curl -k)
  SPA API:  https://${ip:-127.0.0.1}:44300/api
  Login:    ${PBX3_ADMIN_EMAIL}

Firewall: UFW left SSH :22 and API :44300 open from anywhere so install
cannot lock you out. In Admin → Firewall, narrow those Source fields to
your ops/VPN CIDR(s), then Save and Apply (lab LAN is usually enough).

Next: Adopt from Fleet (Instances → Register instance).
If SIP lab: install SBC on amd64 VM, set PBX3_SBC_ADMIN_API_URL on control, Provision edge
(home IP is auto-whitelisted on the SBC).

Fleet lab: fleet-posture + Egress + pjsip_ready symlinks were verified at end of install.

EOF
