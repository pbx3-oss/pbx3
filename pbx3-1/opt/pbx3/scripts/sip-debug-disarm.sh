#!/bin/bash
# Disarm home SIP debug session. Spec: HOME_SIP_LOGGING_REQUIREMENTS.md
set -euo pipefail
# shellcheck source=/dev/null
. /opt/pbx3/scripts/sip-debug-lib.sh

had_pcap=false
if [[ -f "$STATE_FILE" ]]; then
	had_pcap=$(sip_debug_json_get pcap false)
fi

"$ASTERISK" -rx "pjsip set logger off" >/dev/null 2>&1 || true
sip_debug_rotate_text

# After session pcap (or always on fleet nodes), restore fleet-safe default.
if [[ -x "$MODE_SCRIPT" ]]; then
	if [[ "$had_pcap" == "true" ]] || sip_debug_fleet_mode; then
		"$MODE_SCRIPT" fleet || true
	fi
fi

sip_debug_cancel_ttl
sip_debug_write_state false false false "" 0
echo "sip-debug disarmed"
