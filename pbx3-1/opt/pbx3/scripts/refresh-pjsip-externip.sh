#!/bin/sh
# Rewrite PJSIP external_media_address / external_signaling_address to this node's
# current public IP (EIP or auto-assigned). Donor backups still carry the old IP;
# after Mode 4 / SPA Asterisk restore that leaves transport-udp broken or NAT wrong.
#
# Usage (root or via syshelper):
#   refresh-pjsip-externip.sh           # detect IP, rewrite, restart asterisk
#   refresh-pjsip-externip.sh --no-restart
#   PBX3_EXTERNIP=1.2.3.4 refresh-pjsip-externip.sh
#
# Detection mirrors NetHelperClass::get_externip (dig OpenDNS, then ipify).

set -eu

NO_RESTART=0
while [ $# -gt 0 ]; do
	case "$1" in
		--no-restart) NO_RESTART=1; shift ;;
		-h|--help)
			sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "refresh-pjsip-externip: unknown option: $1" >&2
			exit 1
			;;
	esac
done

if [ "$(id -u)" -ne 0 ]; then
	echo "refresh-pjsip-externip: run as root (or via syshelper)" >&2
	exit 1
fi

is_ipv4() {
	case "$1" in
		*.*.*.*)
			# rough check; dig/ipify return clean IPv4 when successful
			echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
			;;
		*) return 1 ;;
	esac
}

detect_externip() {
	if [ -n "${PBX3_EXTERNIP:-}" ] && is_ipv4 "$PBX3_EXTERNIP"; then
		echo "$PBX3_EXTERNIP"
		return 0
	fi
	_ip=""
	if command -v dig >/dev/null 2>&1; then
		_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -1 | tr -d '[:space:]') || true
	fi
	if [ -z "$_ip" ] || ! is_ipv4 "$_ip"; then
		if command -v curl >/dev/null 2>&1; then
			_ip=$(curl -fsS --connect-timeout 5 https://api.ipify.org 2>/dev/null | tr -d '[:space:]') || true
		fi
	fi
	if [ -n "$_ip" ] && is_ipv4 "$_ip"; then
		echo "$_ip"
		return 0
	fi
	return 1
}

rewrite_transport() {
	_file=$1
	_ip=$2
	[ -f "$_file" ] || return 0
	if grep -q '^external_media_address=' "$_file" 2>/dev/null; then
		sed -i "s/^external_media_address=.*/external_media_address=${_ip}/" "$_file"
	fi
	if grep -q '^external_signaling_address=' "$_file" 2>/dev/null; then
		sed -i "s/^external_signaling_address=.*/external_signaling_address=${_ip}/" "$_file"
	fi
	# Keep ownership if asterisk user exists
	if id asterisk >/dev/null 2>&1; then
		chown asterisk:asterisk "$_file" 2>/dev/null || true
	fi
	chmod 664 "$_file" 2>/dev/null || true
	echo "refresh-pjsip-externip: updated $_file → ${_ip}"
}

if ! EXTERNIP=$(detect_externip); then
	echo "refresh-pjsip-externip: could not detect public IP (set PBX3_EXTERNIP=…)" >&2
	exit 1
fi

rewrite_transport /etc/asterisk/pjsip_transport.conf "$EXTERNIP"
# Package/generator copy (may differ from /etc/asterisk after restore)
rewrite_transport /opt/pbx3/etc/asterisk/configs/pjsip_transport.conf "$EXTERNIP"

if [ "$NO_RESTART" -eq 1 ]; then
	echo "refresh-pjsip-externip: skip Asterisk restart (--no-restart)"
	exit 0
fi

if command -v systemctl >/dev/null 2>&1; then
	echo "refresh-pjsip-externip: restarting asterisk (transport bind needs full restart)"
	systemctl restart asterisk
else
	echo "refresh-pjsip-externip: systemctl missing — restart asterisk manually" >&2
	exit 1
fi

exit 0
