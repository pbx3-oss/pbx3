#!/bin/bash
# Enable or disable instance SIP pcap capture (sys-ua-siplog / dumpcap).
#
# Fleet: phones terminate on the SBC — instance :5060 is SBC↔Asterisk only.
#   Default = off (service "down" file). See FLEET_LOG_RETENTION_REQUIREMENTS.md R3.
# Solo/singleton: instance is the edge — turn on for debugging.
#
# Usage:
#   sudo /opt/pbx3/scripts/siplog-set-mode.sh fleet
#   sudo /opt/pbx3/scripts/siplog-set-mode.sh solo
#   sudo /opt/pbx3/scripts/siplog-set-mode.sh status

set -euo pipefail

SVC_DIR=/opt/pbx3/service/sys-ua-siplog
LINK=/etc/service/sys-ua-siplog
MODE="${1:-}"

if [[ ! -d "$SVC_DIR" ]]; then
	echo "siplog service directory missing: $SVC_DIR" >&2
	exit 1
fi

chmod +x "$SVC_DIR/run" 2>/dev/null || true
[[ ! -L "$LINK" ]] && ln -sf "$SVC_DIR" "$LINK"

case "$MODE" in
	fleet|off|disable)
		touch "$SVC_DIR/down"
		sv d sys-ua-siplog 2>/dev/null || true
		echo "sys-ua-siplog: down (fleet/default)"
		sv status sys-ua-siplog 2>/dev/null || true
		;;
	solo|on|enable)
		rm -f "$SVC_DIR/down"
		sv u sys-ua-siplog 2>/dev/null || true
		echo "sys-ua-siplog: up (solo/debug)"
		sv status sys-ua-siplog 2>/dev/null || true
		;;
	status)
		if [[ -f "$SVC_DIR/down" ]]; then
			echo "mode file: down (fleet default)"
		else
			echo "mode file: no down (allowed to run)"
		fi
		sv status sys-ua-siplog 2>/dev/null || echo "sv status unavailable"
		;;
	*)
		echo "Usage: $0 fleet|solo|status" >&2
		exit 2
		;;
esac
