#!/bin/bash
# Apply active TLS certificate: write nginx snippet and Asterisk http.conf, then reload.
# See pbx3/workingdocs/TLS_AND_CERTIFICATES.md
# Selection order: custom -> Let's Encrypt -> snakeoil. See also CERTIFICATES_PANEL_AND_API.md.
# Called by: API (after custom install/remove), certbot deploy-hook (after LE renew).

set -e
CUSTOM_FULLCHAIN="/opt/pbx3/etc/ssl/custom/fullchain.pem"
CUSTOM_PRIVKEY="/opt/pbx3/etc/ssl/custom/privkey.pem"
LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"
TLS_ACTIVE_JSON="/opt/pbx3/etc/identity/tls-active.json"
LE_LIVE_BASE="/etc/letsencrypt/live"
NGINX_SNIPPET="/etc/nginx/snippets/pbx3-ssl-active.conf"
HTTP_CONF="/opt/pbx3/etc/asterisk/configs/http.conf"
SNAKEOIL_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
SNAKEOIL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"

if [ -f "$CUSTOM_FULLCHAIN" ] && [ -f "$CUSTOM_PRIVKEY" ]; then
  CERT="$CUSTOM_FULLCHAIN"
  KEY="$CUSTOM_PRIVKEY"
  TLS_SOURCE="custom"
elif [ -f "$LE_DOMAIN_FILE" ]; then
  domain=$(cat "$LE_DOMAIN_FILE" | tr -d '\n')
  if [ -n "$domain" ] && [ -f "$LE_LIVE_BASE/$domain/fullchain.pem" ] && [ -f "$LE_LIVE_BASE/$domain/privkey.pem" ]; then
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
  sed -i "s|^tlscertfile=.*|tlscertfile=$CERT|" "$HTTP_CONF"
  sed -i "s|^tlsprivatekey=.*|tlsprivatekey=$KEY|" "$HTTP_CONF"
fi
if command -v asterisk >/dev/null 2>&1; then
  asterisk -rx 'core reload' 2>/dev/null || true
fi
