#!/bin/bash
# Arm home SIP debug session (text + optional pcap). Spec: HOME_SIP_LOGGING_REQUIREMENTS.md
set -euo pipefail
# shellcheck source=/dev/null
. /opt/pbx3/scripts/sip-debug-lib.sh

ttl=30
want_pcap=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--ttl) ttl="${2:-30}"; shift 2 ;;
		--pcap) want_pcap=1; shift ;;
		-h|--help) echo "Usage: $0 [--ttl 15-60] [--pcap]"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
done
if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 15 ]] || [[ "$ttl" -gt 60 ]]; then
	echo "ttl must be integer 15–60 (got: $ttl)" >&2
	exit 2
fi

sip_debug_ensure_logger_channel
# Fresh clean text for this session (move any prior content aside).
if [[ -f "$SIP_TEXT" ]] && [[ -s "$SIP_TEXT" ]]; then
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	mv "$SIP_TEXT" "${SIP_TEXT}.${stamp}" 2>/dev/null || : >"$SIP_TEXT"
fi
sip_debug_touch_logs
: >"$SIP_TEXT_RAW" 2>/dev/null || truncate -s 0 "$SIP_TEXT_RAW" 2>/dev/null || true
sip_debug_start_filter
"$ASTERISK" -rx "pjsip set logger on" >/dev/null 2>&1 || echo "warn: pjsip set logger on failed" >&2

if [[ "$want_pcap" -eq 1 ]]; then
	mkdir -p "$SIPLOG_DIR"
	if [[ -x "$MODE_SCRIPT" ]]; then
		"$MODE_SCRIPT" solo || true
	else
		rm -f /opt/pbx3/service/sys-ua-siplog/down
		sv u sys-ua-siplog 2>/dev/null || true
	fi
fi

expires=$(python3 -c "from datetime import datetime,timedelta,timezone; print((datetime.now(timezone.utc)+timedelta(minutes=int('${ttl}'))).strftime('%Y-%m-%dT%H:%M:%SZ'))")
pcap_json=false
[[ "$want_pcap" -eq 1 ]] && pcap_json=true
sip_debug_write_state true true "$pcap_json" "$expires" "$ttl"
sip_debug_schedule_ttl "$ttl"
echo "sip-debug armed: text=on pcap=${pcap_json} ttl=${ttl}m expires=${expires}"
echo "note: home captures SBC↔Asterisk only (not desk REGISTER)"
