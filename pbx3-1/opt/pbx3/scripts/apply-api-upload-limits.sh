#!/bin/sh
# Apply API multipart upload limits (MOH / backups) on an existing home.
# Idempotent: safe from pbx3 postinst and from tip-upgrade ops.
#
# Installs PHP-FPM (+ CLI) 99-pbx3-uploads.ini and ensures nginx
# client_max_body_size 50M on the pbx3-api site when present.
#
# Usage: sudo /opt/pbx3/scripts/apply-api-upload-limits.sh
set -eu

SYSPATH="${SYSPATH:-/opt/pbx3}"
INI_SRC="${PBX3_UPLOADS_INI:-$SYSPATH/etc/php/99-pbx3-uploads.ini}"
BODY_SIZE="${PBX3_CLIENT_MAX_BODY_SIZE:-50M}"

log() { echo "apply-api-upload-limits: $*"; }

if [ ! -f "$INI_SRC" ]; then
	log "missing $INI_SRC — skip"
	exit 0
fi

# Detect phpX.Y-fpm from running unit or installed packages.
php_short=""
if command -v php >/dev/null 2>&1; then
	php_short="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
fi
if [ -z "$php_short" ]; then
	for cand in /etc/php/*/fpm; do
		[ -d "$cand" ] || continue
		php_short="$(basename "$(dirname "$cand")")"
		break
	done
fi

if [ -n "$php_short" ] && [ -d "/etc/php/${php_short}/fpm/conf.d" ]; then
	cp "$INI_SRC" "/etc/php/${php_short}/fpm/conf.d/99-pbx3-uploads.ini"
	log "installed /etc/php/${php_short}/fpm/conf.d/99-pbx3-uploads.ini"
	if [ -d "/etc/php/${php_short}/cli/conf.d" ]; then
		cp "$INI_SRC" "/etc/php/${php_short}/cli/conf.d/99-pbx3-uploads.ini"
	fi
	if systemctl is-active --quiet "php${php_short}-fpm" 2>/dev/null; then
		systemctl reload "php${php_short}-fpm" >/dev/null 2>&1 \
			|| systemctl restart "php${php_short}-fpm" >/dev/null 2>&1 \
			|| true
		log "reloaded php${php_short}-fpm"
	fi
else
	log "php-fpm conf.d not found — skip PHP ini (api not installed yet?)"
fi

patch_nginx_site() {
	site="$1"
	[ -f "$site" ] || return 0
	if grep -qE 'client_max_body_size[[:space:]]+' "$site"; then
		sed -i -E "s/client_max_body_size[[:space:]]+[0-9]+[mMkKgG]?/client_max_body_size ${BODY_SIZE}/" "$site"
	else
		# Insert inside first server { block after the opening brace.
		sed -i -E "0,/server[[:space:]]*\{/s//&\\n    client_max_body_size ${BODY_SIZE};/" "$site"
	fi
	log "nginx $site → client_max_body_size ${BODY_SIZE}"
}

for site in \
	/etc/nginx/sites-enabled/pbx3-api.conf \
	/etc/nginx/sites-available/pbx3-api.conf
do
	# Prefer real file; skip if symlink duplicate of one we already patched.
	if [ -f "$site" ] || [ -L "$site" ]; then
		patch_nginx_site "$site"
	fi
done

if command -v nginx >/dev/null 2>&1; then
	if nginx -t >/dev/null 2>&1; then
		systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1 || true
		log "reloaded nginx"
	else
		log "nginx -t failed — left config; fix manually"
	fi
fi

log "done"
