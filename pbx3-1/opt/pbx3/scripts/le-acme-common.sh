#!/bin/bash
# Shared Let's Encrypt helpers (HTTP-01 webroot by default).
# Sourced by le-first-cert*.sh, le-sync-cert-sans.sh, le-renew-with-80.sh, le-instance-bootstrap.sh.
# PBX3_LE_STAGING=1     -> certbot --test-cert (staging CA)
# PBX3_LE_STANDALONE=1   -> certbot --standalone (break-glass; stops needing nginx webroot)

LE_WEBROOT=/opt/pbx3/var/acme-challenge
LE_DOMAIN_FILE=/opt/pbx3/etc/identity/le-domain

# Run a script whether or not the .deb left +x (invoke via sh).
le_run_script() {
	/bin/sh "$@"
}

ensure_le_webroot() {
	mkdir -p "$LE_WEBROOT"
	chown www-data:www-data "$LE_WEBROOT" 2>/dev/null || true
	chmod 755 "$LE_WEBROOT"
}

le_certbot_staging_args() {
	[ "${PBX3_LE_STAGING:-}" = "1" ] && printf '%s' '--test-cert'
}

# Prints certbot authenticator args (webroot or standalone).
le_certbot_auth_args() {
	if [ "${PBX3_LE_STANDALONE:-}" = "1" ]; then
		printf '%s' '--standalone'
	else
		ensure_le_webroot
		printf '%s' "--webroot -w $LE_WEBROOT"
	fi
}

le_nginx_acme_configured() {
	[ -f /etc/nginx/sites-enabled/pbx3-acme-http.conf ] || \
		[ -f /etc/nginx/sites-available/pbx3-acme-http.conf ]
}

le_require_nginx_for_webroot() {
	if [ "${PBX3_LE_STANDALONE:-}" = "1" ]; then
		return 0
	fi
	if ! le_nginx_acme_configured; then
		echo "ERROR: nginx ACME site missing (install pbx3api nginx or enable pbx3-acme-http.conf)." >&2
		return 1
	fi
	if ! command -v nginx >/dev/null 2>&1; then
		echo "ERROR: nginx not installed." >&2
		return 1
	fi
	if ! nginx -t >/dev/null 2>&1; then
		echo "ERROR: nginx -t failed; fix config before LE." >&2
		return 1
	fi
	systemctl is-active --quiet nginx 2>/dev/null || systemctl start nginx 2>/dev/null || true
	return 0
}
