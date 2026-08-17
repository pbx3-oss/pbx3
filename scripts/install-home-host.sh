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
  local cur ans
  cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    home_err "non-interactive: set $var"
    return 1
  fi
  read -r -s -p "$question: " ans || true
  echo
  if [[ -z "$ans" ]]; then
    home_err "password cannot be empty"
    return 1
  fi
  printf -v "$var" '%s' "$ans"
}

find_deb() {
  local f
  if [[ -n "$PBX3_DEB" && -f "$PBX3_DEB" ]]; then
    printf '%s' "$PBX3_DEB"
    return 0
  fi
  for f in \
    "${SCRIPT_DIR}"/pbx3_*.deb \
    /tmp/pbx3_*.deb \
    "${PWD}"/pbx3_*.deb; do
    if [[ -f "$f" ]]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
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

arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
if [[ "$arch" != "amd64" ]]; then
  INSTALL_CAGI=0
fi

home_prompt DOMAIN_TLD "Domain apex (FQDN becomes {shortuid}.apex)" "pbx3.com"
home_prompt INSTANCE_SITENAME "Site name (friendly Name)" "Lab Home"
home_prompt PBX3_ADMIN_EMAIL "Admin SPA email (not a docs placeholder)"
home_prompt_secret PBX3_ADMIN_PASSWORD "Admin SPA password (min 8 chars)"

if [[ ${#PBX3_ADMIN_PASSWORD} -lt 8 ]]; then
  home_err "admin password must be at least 8 characters"
  exit 1
fi

deb=""
if dpkg-query -W pbx3 >/dev/null 2>&1; then
  home_log "pbx3 already installed ($(dpkg-query -W -f '${Version}' pbx3))"
else
  if ! deb="$(find_deb)"; then
    home_err "pbx3_*.deb not found (set PBX3_DEB or copy next to this script / into /tmp)"
    exit 1
  fi
  home_log "Installing $deb"
  export DEBIAN_FRONTEND=noninteractive
  echo 'slapd slapd/no_configuration boolean true' | debconf-set-selections
  apt-get update -qq
  apt-get install -y ssmtp sqlite3 curl ca-certificates git
  chmod +x /etc/ssmtp 2>/dev/null || true
  apt-get install -y "$deb"
fi

if [[ "$INSTALL_CAGI" == "1" ]]; then
  home_log "CAGI requested — install pbx3cagi_*.deb yourself (not this Lab default)"
else
  home_log "Skipping CAGI (Lab / arch=${arch})"
fi

export DOMAIN_TLD INSTANCE_SITENAME PBX3_ADMIN_EMAIL PBX3_ADMIN_PASSWORD
home_log "Running pbx3 installer.sh"
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

ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
ip="${ip:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
ident="$(sqlite3 /opt/pbx3/db/sqlite.db "SELECT id, shortuid, fqdn, sitename FROM globals WHERE pkey='global';" 2>/dev/null || true)"

cat <<EOF

Home PBX ready (Lab). No Let's Encrypt; API is snakeoil on :44300.

  Identity: ${ident}
  Health:   https://${ip:-127.0.0.1}:44300/up   (curl -k)
  SPA API:  https://${ip:-127.0.0.1}:44300/api
  Login:    ${PBX3_ADMIN_EMAIL}

Next: Adopt from Fleet (Instances → Register instance). Skip Provision edge (no SIP).

EOF
