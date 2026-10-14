#!/bin/bash
# Split Asterisk security events into their own log file so messages stays human-readable.
# Idempotent. Spec note: FLEET_LOG_RETENTION_REQUIREMENTS.md (security channel).
#
#   messages => notice,warning,error,verbose
#   security => security   → /var/log/asterisk/security
#
# Keep verbose on messages so console "core set verbose N" still lands there.
#
# Fail2ban home [asterisk] jail (disabled on fleet) and pbx3:ops-register-loops
# read the security file.
set -euo pipefail

LOGGER_CONF="${PBX3_LOGGER_CONF:-/etc/asterisk/logger.conf}"
SECURITY_LOG="${PBX3_ASTERISK_SECURITY_LOG:-/var/log/asterisk/security}"
ASTERISK="${PBX3_ASTERISK_EXEC:-/usr/sbin/asterisk}"
RELOAD="${PBX3_LOGGER_RELOAD:-1}"

[[ -f "$LOGGER_CONF" ]] || exit 0

need_reload=0

# Portable in-place edit (GNU + BSD sed)
pbx3_sed_i() {
	local expr=$1 file=$2
	local tmp="${file}.pbx3-logger.tmp"
	sed -E "$expr" "$file" > "$tmp"
	mv "$tmp" "$file"
}

pbx3_insert_under_logfiles() {
	local line=$1
	awk -v line="$line" '
		BEGIN { done=0 }
		/^\[logfiles\]/ { print; insec=1; next }
		insec && /^\[/ && !done { print line; done=1; insec=0 }
		{ print }
		END { if (insec && !done) print line }
	' "$LOGGER_CONF" > "${LOGGER_CONF}.pbx3-logger.tmp"
	mv "${LOGGER_CONF}.pbx3-logger.tmp" "$LOGGER_CONF"
}

# Date format (same as installer / setip)
if grep -qE '^;dateformat=%F %T ' "$LOGGER_CONF" 2>/dev/null; then
	pbx3_sed_i 's/^;dateformat=%F %T /dateformat=%F %T/' "$LOGGER_CONF"
	need_reload=1
fi

# Canonical messages line — no security level mixed in; keep verbose for console control
desired_messages='messages => notice,warning,error,verbose'
if grep -qE '^[[:space:]]*messages[[:space:]]*=>' "$LOGGER_CONF"; then
	cur=$(grep -E '^[[:space:]]*messages[[:space:]]*=>' "$LOGGER_CONF" | head -1 | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//')
	if [[ "$cur" != "$desired_messages" ]]; then
		pbx3_sed_i 's/^[[:space:]]*messages[[:space:]]*=>.*/'"$desired_messages"'/' "$LOGGER_CONF"
		need_reload=1
	fi
else
	if grep -qE '^\[logfiles\]' "$LOGGER_CONF"; then
		pbx3_insert_under_logfiles "$desired_messages"
		need_reload=1
	else
		printf '\n[logfiles]\n%s\n' "$desired_messages" >> "$LOGGER_CONF"
		need_reload=1
	fi
fi

# Dedicated security channel
desired_security='security => security'
if ! grep -qE '^[[:space:]]*security[[:space:]]*=>' "$LOGGER_CONF"; then
	if grep -qE '^\[logfiles\]' "$LOGGER_CONF"; then
		pbx3_insert_under_logfiles "$desired_security"
	else
		printf '\n[logfiles]\n%s\n' "$desired_security" >> "$LOGGER_CONF"
	fi
	need_reload=1
else
	cur=$(grep -E '^[[:space:]]*security[[:space:]]*=>' "$LOGGER_CONF" | head -1 | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//')
	if [[ "$cur" != "$desired_security" ]]; then
		pbx3_sed_i 's/^[[:space:]]*security[[:space:]]*=>.*/'"$desired_security"'/' "$LOGGER_CONF"
		need_reload=1
	fi
fi

mkdir -p "$(dirname "$SECURITY_LOG")"
touch "$SECURITY_LOG"
chown asterisk:asterisk "$SECURITY_LOG" 2>/dev/null || true
chmod 640 "$SECURITY_LOG" 2>/dev/null || true

if [[ "$need_reload" -eq 1 && "$RELOAD" = "1" ]]; then
	"$ASTERISK" -rx 'logger reload' >/dev/null 2>&1 || true
fi

exit 0
