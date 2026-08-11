#!/bin/bash
# Session-armed home SIP debug — shared helpers.
# Spec: HOME_SIP_LOGGING_REQUIREMENTS.md
#
# Asterisk verbose is noisy (all modules). We log verbose to sip-debug-raw and
# filter res_pjsip_logger frames into sip-debug (the SPA / AI surface).
set -euo pipefail

STATE_DIR=/opt/pbx3/var/sip-debug
STATE_FILE="${STATE_DIR}/state.json"
FILTER_PID_FILE="${STATE_DIR}/filter.pid"
SIP_TEXT=/var/log/asterisk/sip-debug
SIP_TEXT_RAW=/var/log/asterisk/sip-debug-raw
SIPLOG_DIR=/opt/pbx3/db/var/log/siplog
LOGGER_CONF=/etc/asterisk/logger.conf
MODE_SCRIPT=/opt/pbx3/scripts/siplog-set-mode.sh
FILTER_RUN=/opt/pbx3/scripts/sip-debug-filter-run.sh
ASTERISK="${PBX3_ASTERISK_EXEC:-/usr/sbin/asterisk}"
TTL_UNIT=sip-debug-ttl.timer
TTL_SERVICE=sip-debug-ttl.service

mkdir -p "$STATE_DIR"

sip_debug_touch_logs() {
	touch "$SIP_TEXT" "$SIP_TEXT_RAW"
	chown asterisk:asterisk "$SIP_TEXT" "$SIP_TEXT_RAW" 2>/dev/null || true
	chmod 640 "$SIP_TEXT" "$SIP_TEXT_RAW" 2>/dev/null || true
}

# Ensure Asterisk writes verbose only to sip-debug-raw (not the clean sip-debug file).
sip_debug_ensure_logger_channel() {
	[[ -f "$LOGGER_CONF" ]] || return 0
	local need_reload=0
	# Drop legacy direct sip-debug => verbose (pollutes clean file).
	if grep -qE '^[[:space:]]*sip-debug[[:space:]]*=>' "$LOGGER_CONF"; then
		sed -i -E '/^[[:space:]]*sip-debug[[:space:]]*=>/d' "$LOGGER_CONF"
		need_reload=1
	fi
	if ! grep -qE '^[[:space:]]*sip-debug-raw[[:space:]]*=>' "$LOGGER_CONF"; then
		if grep -qE '^\[logfiles\]' "$LOGGER_CONF"; then
			awk '
				BEGIN { done=0 }
				/^\[logfiles\]/ { print; insec=1; next }
				insec && /^\[/ && !done {
					print "sip-debug-raw => verbose"
					done=1
					insec=0
				}
				{ print }
				END { if (insec && !done) print "sip-debug-raw => verbose" }
			' "$LOGGER_CONF" > "${LOGGER_CONF}.pbx3-sip-debug.tmp"
			mv "${LOGGER_CONF}.pbx3-sip-debug.tmp" "$LOGGER_CONF"
		else
			printf '\n[logfiles]\nsip-debug-raw => verbose\n' >> "$LOGGER_CONF"
		fi
		need_reload=1
	fi
	sip_debug_touch_logs
	if [[ "$need_reload" -eq 1 ]]; then
		"$ASTERISK" -rx "logger reload" >/dev/null 2>&1 || true
	fi
}

sip_debug_stop_filter() {
	if [[ -f "$FILTER_PID_FILE" ]]; then
		local pid
		pid=$(cat "$FILTER_PID_FILE" 2>/dev/null || true)
		if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			sleep 0.2
			kill -9 "$pid" 2>/dev/null || true
		fi
		rm -f "$FILTER_PID_FILE"
	fi
	# Also reap stray filters
	pkill -f '/opt/pbx3/scripts/sip-debug-filter-run.sh' 2>/dev/null || true
}

sip_debug_start_filter() {
	sip_debug_stop_filter
	sip_debug_touch_logs
	if [[ ! -x "$FILTER_RUN" ]]; then
		echo "warn: $FILTER_RUN missing — SIP text will stay empty" >&2
		return 0
	fi
	nohup "$FILTER_RUN" >>"${STATE_DIR}/filter.log" 2>&1 &
	echo $! >"$FILTER_PID_FILE"
}

sip_debug_rotate_text() {
	sip_debug_stop_filter
	if [[ -f "$SIP_TEXT" ]] && [[ -s "$SIP_TEXT" ]]; then
		local stamp dest
		stamp=$(date -u +%Y%m%dT%H%M%SZ)
		dest="${SIP_TEXT}.${stamp}"
		mv "$SIP_TEXT" "$dest" 2>/dev/null || true
	fi
	# Truncate raw for next session (copytruncate-friendly)
	if [[ -f "$SIP_TEXT_RAW" ]]; then
		: >"$SIP_TEXT_RAW" 2>/dev/null || truncate -s 0 "$SIP_TEXT_RAW" 2>/dev/null || true
	fi
	sip_debug_touch_logs
}

sip_debug_cancel_ttl() {
	systemctl stop "$TTL_UNIT" 2>/dev/null || true
	rm -f /etc/systemd/system/"$TTL_UNIT" /etc/systemd/system/"$TTL_SERVICE" 2>/dev/null || true
	systemctl daemon-reload 2>/dev/null || true
}

sip_debug_schedule_ttl() {
	local minutes="$1"
	sip_debug_cancel_ttl
	cat > /etc/systemd/system/"$TTL_SERVICE" <<EOF
[Unit]
Description=PBX3 SIP debug session TTL disarm
[Service]
Type=oneshot
ExecStart=/opt/pbx3/scripts/sip-debug-disarm.sh
EOF
	cat > /etc/systemd/system/"$TTL_UNIT" <<EOF
[Unit]
Description=PBX3 SIP debug session TTL (${minutes}m)
[Timer]
OnActiveSec=${minutes}min
AccuracySec=1s
Unit=${TTL_SERVICE}
[Install]
WantedBy=timers.target
EOF
	systemctl daemon-reload
	systemctl start "$TTL_UNIT"
}

sip_debug_write_state() {
	local armed="$1" text="$2" pcap="$3" expires="$4" ttl_min="$5"
	cat > "$STATE_FILE" <<EOF
{
  "armed": ${armed},
  "text": ${text},
  "pcap": ${pcap},
  "expires_at": "${expires}",
  "ttl_minutes": ${ttl_min},
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

sip_debug_fleet_mode() {
	if [[ -n "${PBX3_FLEET_MODE:-}" ]]; then
		return 0
	fi
	if [[ -f /opt/pbx3api/.env ]] && grep -qE '^PBX3_FLEET_MODE=(1|true|yes)' /opt/pbx3api/.env 2>/dev/null; then
		return 0
	fi
	[[ -f /opt/pbx3/service/sys-ua-siplog/down ]]
}

sip_debug_json_get() {
	local key="$1" default="${2:-}"
	python3 -c 'import json,sys
p,k,d=sys.argv[1],sys.argv[2],sys.argv[3]
try:
  v=json.load(open(p)).get(k, d)
  if isinstance(v, bool):
    print("true" if v else "false")
  elif v is None:
    print(d)
  else:
    print(v)
except Exception:
  print(d)
' "$STATE_FILE" "$key" "$default" 2>/dev/null || echo "$default"
}
