#!/bin/bash
# Install pbx3-acme-http.conf into nginx (HTTP-01 webroot on port 80).
# Run as root. Called by pbx3 installer or manually after pbx3api deploy.

set -e
SYSPATH="${SYSPATH:-/opt/pbx3}"
SRC="$SYSPATH/etc/nginx/pbx3-acme-http.conf"
AVAIL="/etc/nginx/sites-available/pbx3-acme-http.conf"
ENABLED="/etc/nginx/sites-enabled/pbx3-acme-http.conf"

if [ ! -f "$SRC" ]; then
	echo "Missing $SRC" >&2
	exit 1
fi
if ! command -v nginx >/dev/null 2>&1; then
	echo "nginx not installed; skip ACME site (install pbx3api for nginx)." >&2
	exit 0
fi

mkdir -p /opt/pbx3/var/acme-challenge
chown www-data:www-data /opt/pbx3/var/acme-challenge 2>/dev/null || true
chmod 755 /opt/pbx3/var/acme-challenge

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
cp -f "$SRC" "$AVAIL"
ln -sfn "$AVAIL" "$ENABLED"
nginx -t
systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
echo "Installed nginx ACME site: $ENABLED (webroot /opt/pbx3/var/acme-challenge)"
