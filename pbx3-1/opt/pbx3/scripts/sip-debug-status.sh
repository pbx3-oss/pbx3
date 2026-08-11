#!/bin/bash
# Status JSON for home SIP debug session. Spec: HOME_SIP_LOGGING_REQUIREMENTS.md
set -euo pipefail
# shellcheck source=/dev/null
. /opt/pbx3/scripts/sip-debug-lib.sh

armed=false
text=false
pcap=false
expires_at=""
ttl_remaining_sec=0

if [[ -f "$STATE_FILE" ]]; then
	armed=$(sip_debug_json_get armed false)
	text=$(sip_debug_json_get text false)
	pcap=$(sip_debug_json_get pcap false)
	expires_at=$(sip_debug_json_get expires_at "")
	if [[ -n "$expires_at" && "$expires_at" != "" ]]; then
		ttl_remaining_sec=$(python3 -c '
from datetime import datetime, timezone
import sys
exp=sys.argv[1].replace("Z","+00:00")
try:
  dt=datetime.fromisoformat(exp)
  now=datetime.now(timezone.utc)
  print(max(0, int((dt-now).total_seconds())))
except Exception:
  print(0)
' "$expires_at")
	fi
fi

pcap_running=false
if command -v sv >/dev/null 2>&1 && sv status sys-ua-siplog 2>/dev/null | grep -q '^run:'; then
	pcap_running=true
fi

# Bash true/false → Python True/False for json.dumps
py_bool() { [[ "$1" == "true" ]] && echo True || echo False; }

python3 - <<PY
import json
print(json.dumps({
  "armed": $(py_bool "$armed"),
  "text": $(py_bool "$text"),
  "pcap": $(py_bool "$pcap"),
  "pcap_running": $(py_bool "$pcap_running"),
  "expires_at": """${expires_at}""",
  "ttl_remaining_sec": int("""${ttl_remaining_sec}""" or 0),
  "sip_text_path": "${SIP_TEXT}",
  "siplog_dir": "${SIPLOG_DIR}",
}, indent=2))
PY
