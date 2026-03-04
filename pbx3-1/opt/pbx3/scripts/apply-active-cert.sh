#!/bin/bash
# Apply active TLS certificate: write nginx snippet and Asterisk http.conf, then reload.
# Selection order: custom -> Let's Encrypt -> snakeoil. See CERTIFICATES_ADOPTION_PLAN.md.
# Called by: API (after custom install/remove), certbot deploy-hook (after LE renew).

set -e
CUSTOM_FULLCHAIN="/opt/pbx3/etc/ssl/custom/fullchain.pem"
CUSTOM_PRIVKEY="/opt/pbx3/etc/ssl/custom/privkey.pem"
LE_DOMAIN_FILE="/opt/pbx3/etc/identity/le-domain"
LE_LIVE_BASE="/etc/letsencrypt/live"
NGINX_SNIPPET="/etc/nginx/snippets/pbx3-ssl-active.conf"
HTTP_CONF="/opt/pbx3/etc/asterisk/configs/http.conf"
SNAKEOIL_CERT="/etc/ssl/certs/ssl-cert-snakeoil.pem"
SNAKEOIL_KEY="/etc/ssl/private/ssl-cert-snakeoil.key"

if [ -f "$CUSTOM_FULLCHAIN" ] && [ -f "$CUSTOM_PRIVKEY" ]; then
  CERT="$CUSTOM_FULLCHAIN"
  KEY="$CUSTOM_PRIVKEY"
elif [ -f "$LE_DOMAIN_FILE" ]; then
  domain=$(cat "$LE_DOMAIN_FILE" | tr -d '\n')
  if [ -n "$domain" ] && [ -f "$LE_LIVE_BASE/$domain/fullchain.pem" ] && [ -f "$LE_LIVE_BASE/$domain/privkey.pem" ]; then
    CERT="$LE_LIVE_BASE/$domain/fullchain.pem"
    KEY="$LE_LIVE_BASE/$domain/privkey.pem"
  else
    CERT="$SNAKEOIL_CERT"
    KEY="$SNAKEOIL_KEY"
  fi
else
  CERT="$SNAKEOIL_CERT"
  KEY="$SNAKEOIL_KEY"
fi

mkdir -p "$(dirname "$NGINX_SNIPPET")" 2>/dev/null || true
printf 'ssl_certificate     %s;\nssl_certificate_key %s;\n' "$CERT" "$KEY" > "$NGINX_SNIPPET"

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
