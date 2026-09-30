#!/bin/sh
# Install home provision nginx listener on :41363.
# Spec: PROVISIONING_IMPLEMENTATION_PLAN.md A5 · PROVISIONING_SERVER_REQUIREMENTS.md §0.3
#
# Usage (root):
#   install-provision-listener.sh              # auto: fleet→HTTP, else HTTPS
#   install-provision-listener.sh fleet|solo   # force mode
#   install-provision-listener.sh http|https   # force listen style
#
# Requires nginx + php-fpm (typically after pbx3api). No-ops with message if missing.
# Idempotent: replaces sites-available/pbx3-provision.conf and enables it.
set -eu

SCRIPTS="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SYSPATH="${PBX3_ROOT:-/opt/pbx3}"
ETC_NGINX="$SYSPATH/etc/nginx"
SITE_NAME="pbx3-provision.conf"
AVAILABLE="/etc/nginx/sites-available/$SITE_NAME"
ENABLED="/etc/nginx/sites-enabled/$SITE_NAME"
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-php8.3-fpm}"
PHP_FPM_SOCKET="${PHP_FPM_SOCKET:-/run/php/${PHP_FPM_SERVICE}.sock}"
API_ENV="${PBX3API_ENV:-/opt/pbx3api/.env}"

MODE="${1:-}"

die() { echo "install-provision-listener: $*" >&2; exit 1; }
log() { echo "install-provision-listener: $*"; }

detect_fleet() {
	# Mirror installer / GenClass: env then Egress trunk.
	if [ -n "${PBX3_FLEET_MODE:-}" ]; then
		case "$(printf '%s' "$PBX3_FLEET_MODE" | tr '[:upper:]' '[:lower:]')" in
			1|true|yes) return 0 ;;
			0|false|no) return 1 ;;
		esac
	fi
	if [ -f "$API_ENV" ]; then
		if grep -qE '^[[:space:]]*PBX3_FLEET_MODE=true' "$API_ENV" 2>/dev/null; then
			return 0
		fi
		if grep -qE '^[[:space:]]*PBX3_SBC_EGRESS_HOST=' "$API_ENV" 2>/dev/null; then
			return 0
		fi
	fi
	if command -v sqlite3 >/dev/null 2>&1 && [ -f "$SYSPATH/db/sqlite.db" ]; then
		act=$(sqlite3 "$SYSPATH/db/sqlite.db" "SELECT active FROM trunks WHERE pkey='Egress' LIMIT 1;" 2>/dev/null || true)
		[ "$act" = "YES" ] && return 0
	fi
	return 1
}

resolve_mode() {
	case "$MODE" in
		fleet|http) echo http; return ;;
		solo|https) echo https; return ;;
		"")
			if detect_fleet; then echo http; else echo https; fi
			return
			;;
		*) die "usage: $0 [fleet|solo|http|https]" ;;
	esac
}

[ "$(id -u)" -eq 0 ] || die "must run as root"
command -v nginx >/dev/null 2>&1 || {
	log "nginx not installed — skip (run again after pbx3api / nginx)"
	exit 0
}

STYLE=$(resolve_mode)
case "$STYLE" in
	http) SRC="$ETC_NGINX/pbx3-provision-http.conf" ;;
	https) SRC="$ETC_NGINX/pbx3-provision-https.conf" ;;
	*) die "internal: bad style $STYLE" ;;
esac
[ -f "$SRC" ] || die "missing template $SRC"

if [ "$STYLE" = "https" ]; then
	SNIPPET="/etc/nginx/snippets/pbx3-ssl-active.conf"
	if [ ! -f "$SNIPPET" ]; then
		log "missing $SNIPPET — running apply-active-cert.sh if present"
		if [ -x "$SCRIPTS/apply-active-cert.sh" ]; then
			"$SCRIPTS/apply-active-cert.sh" || true
		fi
	fi
	[ -f "$SNIPPET" ] || die "HTTPS mode needs $SNIPPET (run apply-active-cert.sh first)"
fi

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets
cp "$SRC" "$AVAILABLE"
# Align fastcgi socket with selected PHP-FPM service.
sed -i "s|fastcgi_pass unix:[^;]*;|fastcgi_pass unix:${PHP_FPM_SOCKET};|g" "$AVAILABLE"

# Disable the other style if a previous install left a differently named site.
rm -f /etc/nginx/sites-enabled/pbx3-provision-http.conf \
	/etc/nginx/sites-enabled/pbx3-provision-https.conf 2>/dev/null || true
ln -sfn "$AVAILABLE" "$ENABLED"

# Ensure provision audit log dir exists (device.php / kernel).
mkdir -p "$SYSPATH/var/log"
chown www-data:www-data "$SYSPATH/var/log" 2>/dev/null || true
chmod 750 "$SYSPATH/var/log" 2>/dev/null || true

nginx -t
systemctl reload nginx 2>/dev/null || systemctl restart nginx

log "enabled $ENABLED (style=$STYLE port=41363 socket=$PHP_FPM_SOCKET)"
if [ "$STYLE" = "https" ]; then
	log "solo RPS URL shape: https://{instance-fqdn}:41363/provisioning/{mac}.cfg"
else
	log "fleet: edge proxies HTTPS → http://{home}:41363/provisioning/… (UFW SBC-only)"
fi
exit 0
