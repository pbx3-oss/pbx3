#!/bin/bash
# Apply active TLS certificate: write nginx snippet and Asterisk http.conf, then reload.
# See pbx3/workingdocs/TLS_AND_CERTIFICATES.md
# Selection order: custom -> Let's Encrypt -> snakeoil. See also CERTIFICATES_PANEL_AND_API.md.
# Called by: API (after custom install/remove), certbot deploy-hook (after LE renew), installer.
#
# WebRTC/WSS: Asterisk HTTP TLS (:8089 /ws) needs to open the private key. Certbot leaves
# /etc/letsencrypt/{live,archive} mode 700 and privkeys 600 root-only — Asterisk then fails
# TLS bind and only :8088 listens. This script makes keys group-readable for ssl-cert and
# restarts Asterisk so WSS actually rebinds.

set -e
CUSTOM_FULLCHAIN="/opt/pbx3/etc/ssl/custom/fullchain.pem"
CUSTOM_PRIVKEY="/opt/pbx3/etc/ssl/custom/privkey.pem"
LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"
TLS_ACTIVE_JSON="/opt/pbx3/etc/identity/tls-active.json"
LE_LIVE_BASE="/etc/letsencrypt/live"
LE_ARCHIVE_BASE="/etc/letsencrypt/archive"
NGINX_SNIPPET="/etc/nginx/snippets/pbx3-ssl-active.conf"
HTTP_CONF="/opt/pbx3/etc/asterisk/configs/http.conf"
SNAKEOIL_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
SNAKEOIL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"

# Ensure processes in group ssl-cert can open keys under /etc/letsencrypt and /etc/ssl/private.
ensure_ssl_cert_principal() {
  if getent group ssl-cert >/dev/null 2>&1; then
    usermod -a -G ssl-cert asterisk 2>/dev/null || true
    usermod -a -G ssl-cert www-data 2>/dev/null || true
  fi
}

# Certbot default ACLs leave live/archive root-only. Group ssl-cert + 640 privkeys.
# Safe no-ops if paths missing or not root.
ensure_le_tree_readable() {
  local domain="$1"
  [ -n "$domain" ] || return 0
  [ -d "$LE_LIVE_BASE" ] || return 0
  getent group ssl-cert >/dev/null 2>&1 || return 0

  chgrp -R ssl-cert "$LE_LIVE_BASE" "$LE_ARCHIVE_BASE" 2>/dev/null || true
  # live + archive tops and domain dirs: traverse for non-root group members
  chmod 750 "$LE_LIVE_BASE" "$LE_ARCHIVE_BASE" 2>/dev/null || true
  [ -d "$LE_LIVE_BASE/$domain" ] && chmod 750 "$LE_LIVE_BASE/$domain" 2>/dev/null || true
  [ -d "$LE_ARCHIVE_BASE/$domain" ] && chmod 750 "$LE_ARCHIVE_BASE/$domain" 2>/dev/null || true
  # Other domain dirs under live/archive (multi-name renewals)
  find "$LE_LIVE_BASE" "$LE_ARCHIVE_BASE" -mindepth 1 -maxdepth 1 -type d -exec chmod 750 {} \; 2>/dev/null || true
  find "$LE_ARCHIVE_BASE" -type d -exec chmod 750 {} \; 2>/dev/null || true
  find "$LE_ARCHIVE_BASE" -name 'privkey*.pem' -exec chgrp ssl-cert {} \; 2>/dev/null || true
  find "$LE_ARCHIVE_BASE" -name 'privkey*.pem' -exec chmod 640 {} \; 2>/dev/null || true
  find "$LE_ARCHIVE_BASE" -name '*.pem' ! -name 'privkey*.pem' -exec chmod 644 {} \; 2>/dev/null || true
}

# Custom material under /opt/pbx3 — allow asterisk via group if owned by root.
ensure_path_group_readable() {
  local path="$1"
  [ -f "$path" ] || return 0
  getent group ssl-cert >/dev/null 2>&1 || return 0
  chgrp ssl-cert "$path" 2>/dev/null || true
  # 640 for keys; 644 for public certs is fine if already world-readable
  case "$path" in
    *privkey*|*key*|*KEY*) chmod 640 "$path" 2>/dev/null || true ;;
    *) chmod a+r "$path" 2>/dev/null || true ;;
  esac
}

ensure_ssl_cert_principal

if [ -f "$CUSTOM_FULLCHAIN" ] && [ -f "$CUSTOM_PRIVKEY" ]; then
  CERT="$CUSTOM_FULLCHAIN"
  KEY="$CUSTOM_PRIVKEY"
  TLS_SOURCE="custom"
  ensure_path_group_readable "$CERT"
  ensure_path_group_readable "$KEY"
elif [ -f "$LE_DOMAIN_FILE" ]; then
  domain=$(tr -d '\n' <"$LE_DOMAIN_FILE")
  if [ -n "$domain" ] && [ -f "$LE_LIVE_BASE/$domain/fullchain.pem" ] && [ -f "$LE_LIVE_BASE/$domain/privkey.pem" ]; then
    ensure_le_tree_readable "$domain"
    CERT="$LE_LIVE_BASE/$domain/fullchain.pem"
    KEY="$LE_LIVE_BASE/$domain/privkey.pem"
    TLS_SOURCE="letsencrypt"
    TLS_DOMAIN="$domain"
  else
    CERT="$SNAKEOIL_CERT"
    KEY="$SNAKEOIL_KEY"
    TLS_SOURCE="snakeoil"
  fi
else
  CERT="$SNAKEOIL_CERT"
  KEY="$SNAKEOIL_KEY"
  TLS_SOURCE="snakeoil"
fi

if [ "$TLS_SOURCE" = "snakeoil" ]; then
  # Ubuntu snakeoil key is typically root:ssl-cert mode 640 once ssl-cert package is present.
  ensure_path_group_readable "$SNAKEOIL_KEY" 2>/dev/null || true
fi

write_tls_active_json() {
  mkdir -p "$(dirname "$TLS_ACTIVE_JSON")"
  local expires issuer expires_json issuer_json domain_json sans_json comma s esc _sans_tmp
  expires=""
  issuer=""
  expires_json="null"
  issuer_json="null"
  domain_json="null"
  sans_json="["
  comma=""
  if [ -f "$CERT" ] && command -v openssl >/dev/null 2>&1; then
    expires=$(openssl x509 -enddate -noout -in "$CERT" 2>/dev/null | sed -n 's/^notAfter=//p' | head -1)
    if [ -n "$expires" ]; then
      expires=$(date -u -d "$expires" '+%Y-%m-%d' 2>/dev/null || true)
    fi
    issuer=$(openssl x509 -noout -issuer -in "$CERT" 2>/dev/null | sed -n 's/^issuer=//p' | head -1)
    _sans_tmp=$(mktemp) || exit 1
    openssl x509 -noout -text -in "$CERT" 2>/dev/null | tr ',' '\n' | sed -n 's/^[[:space:]]*DNS://p' >"$_sans_tmp"
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      esc=$(printf '%s' "$s" | sed 's/\\/\\\\/g; s/"/\\"/g')
      sans_json+="${comma}\"${esc}\""
      comma=","
    done <"$_sans_tmp"
    rm -f "$_sans_tmp"
  fi
  sans_json+="]"
  if [ "$sans_json" = "[]" ] && [ -n "${TLS_DOMAIN:-}" ]; then
    esc=$(printf '%s' "$TLS_DOMAIN" | sed 's/\\/\\\\/g; s/"/\\"/g')
    sans_json="[\"${esc}\"]"
  fi
  if [ -n "$expires" ]; then
    expires_json="\"$expires\""
  fi
  if [ -n "$issuer" ]; then
    esc=$(printf '%s' "$issuer" | sed 's/\\/\\\\/g; s/"/\\"/g')
    issuer_json="\"${esc}\""
  fi
  if [ -n "${TLS_DOMAIN:-}" ]; then
    esc=$(printf '%s' "$TLS_DOMAIN" | sed 's/\\/\\\\/g; s/"/\\"/g')
    domain_json="\"${esc}\""
  fi
  esc=$(printf '%s' "$CERT" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"source":"%s","domain":%s,"fullchain":"%s","expires_at":%s,"issuer":%s,"cert_sans":%s}\n' \
    "${TLS_SOURCE:-snakeoil}" \
    "$domain_json" \
    "$esc" \
    "$expires_json" \
    "$issuer_json" \
    "$sans_json" > "$TLS_ACTIVE_JSON"
  chmod 644 "$TLS_ACTIVE_JSON" 2>/dev/null || true
}

mkdir -p "$(dirname "$NGINX_SNIPPET")" 2>/dev/null || true
printf 'ssl_certificate     %s;\nssl_certificate_key %s;\n' "$CERT" "$KEY" > "$NGINX_SNIPPET"
write_tls_active_json

if command -v systemctl >/dev/null 2>&1; then
  systemctl reload nginx 2>/dev/null || true
fi

if [ -f "$HTTP_CONF" ]; then
  # Paths rewritten here; package default is snakeoil until first apply after LE.
  if grep -q '^tlscertfile=' "$HTTP_CONF" 2>/dev/null; then
    sed -i "s|^tlscertfile=.*|tlscertfile=$CERT|" "$HTTP_CONF"
  else
    echo "tlscertfile=$CERT" >>"$HTTP_CONF"
  fi
  if grep -q '^tlsprivatekey=' "$HTTP_CONF" 2>/dev/null; then
    sed -i "s|^tlsprivatekey=.*|tlsprivatekey=$KEY|" "$HTTP_CONF"
  else
    echo "tlsprivatekey=$KEY" >>"$HTTP_CONF"
  fi
fi

# core reload does not re-open TLS after a failed bind; restart so :8089/WSS sticks.
reload_asterisk_tls() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet asterisk 2>/dev/null; then
    systemctl restart asterisk 2>/dev/null && return 0
  fi
  if command -v asterisk >/dev/null 2>&1; then
    asterisk -rx 'core restart now' 2>/dev/null && return 0
    asterisk -rx 'core reload' 2>/dev/null || true
  fi
}

if command -v asterisk >/dev/null 2>&1 || systemctl list-unit-files asterisk.service >/dev/null 2>&1; then
  reload_asterisk_tls
fi
