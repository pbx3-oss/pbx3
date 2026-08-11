#!/bin/bash
# Extract SIP messages as JSONL for AI/agent debug. Spec: HOME_SIP_LOGGING_REQUIREMENTS.md
set -euo pipefail
# shellcheck source=/dev/null
. /opt/pbx3/scripts/sip-debug-lib.sh

call_id=""
since_min=""
source=auto
want_raw=0
outfile=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--call-id) call_id="${2:-}"; shift 2 ;;
		--since) since_min="${2:-}"; shift 2 ;;
		--source) source="${2:-auto}"; shift 2 ;;
		--raw) want_raw=1; shift ;;
		-o) outfile="${2:-}"; shift 2 ;;
		-h|--help)
			echo "Usage: $0 [--call-id ID] [--since MIN] [--source text|pcap|auto] [--raw] [-o FILE]"
			exit 0
			;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
done

emit_from_text() {
	local file="$1"
	[[ -f "$file" ]] || return 0
	python3 - "$file" "$call_id" "$want_raw" <<'PY'
import json, re, sys
path, call_id, want_raw = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
# Asterisk PJSIP logger lines are verbose dumps; split on blank lines / INVITE markers loosely.
buf = []
msgs = []

def flush():
    global buf
    if not buf:
        return
    text = "\n".join(buf)
    buf = []
    m_method = re.search(r'^\s*(INVITE|ACK|BYE|CANCEL|REGISTER|OPTIONS|SUBSCRIBE|NOTIFY|REFER|UPDATE|PRACK|INFO|MESSAGE|PUBLISH)\b', text, re.M)
    m_status = re.search(r'^\s*SIP/2\.0\s+(\d{3})', text, re.M)
    m_cid = re.search(r'(?i)^Call-ID:\s*(\S+)', text, re.M)
    m_from = re.search(r'(?i)^From:\s*(.+)$', text, re.M)
    m_to = re.search(r'(?i)^To:\s*(.+)$', text, re.M)
    m_ruri = re.search(r'(?i)^(?:INVITE|ACK|BYE|CANCEL|REGISTER|OPTIONS|SUBSCRIBE|NOTIFY|REFER|UPDATE|PRACK|INFO|MESSAGE|PUBLISH)\s+(\S+)', text, re.M)
    m_cseq = re.search(r'(?i)^CSeq:\s*(.+)$', text, re.M)
    m_via = re.search(r'(?i)^Via:[^\n]*branch=([^;\s]+)', text, re.M)
    method = m_method.group(1) if m_method else None
    status = int(m_status.group(1)) if m_status else None
    # Skip logger noise (reload / queue / UNIX connection) — require a SIP start-line.
    if not method and status is None:
        return
    cid = (m_cid.group(1).strip() if m_cid else "")
    if call_id and cid and call_id not in cid:
        return
    m_ts = re.search(r'^---\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\b', text, re.M) or re.search(
        r'^\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]', text, re.M
    )
    m_dir = re.search(r'(Received|Transmitting)\s+SIP', text, re.I)
    direction = None
    if m_dir:
        direction = "in" if m_dir.group(1).lower().startswith("receiv") else "out"
    t_iso = None
    if m_ts:
        # Asterisk logger stamps are node-local wall clock (no TZ in bracket).
        t_iso = m_ts.group(1).replace(" ", "T")
    obj = {
        "t": t_iso,
        "dir": direction,
        "method": method,
        "status": status,
        "call_id": cid or None,
        "from": m_from.group(1).strip() if m_from else None,
        "to": m_to.group(1).strip() if m_to else None,
        "ruri": m_ruri.group(1).strip() if m_ruri else None,
        "cseq": m_cseq.group(1).strip() if m_cseq else None,
        "via_branch": m_via.group(1).strip() if m_via else None,
        "has_body": "\n\n" in text and len(text.split("\n\n", 1)[-1].strip()) > 0,
        "raw": (text[:4000] if want_raw else None),
        "source": "text",
    }
    msgs.append(obj)

with open(path, errors="replace") as f:
    for line in f:
        # Clean filter format: --- ts Transmitting/Received ... ---
        if re.match(r'^---\s+\d{4}-\d{2}-\d{2}', line) and buf:
            flush()
            buf.append(line.rstrip("\n"))
            continue
        if line.strip() == "" and buf:
            flush()
        else:
            # Heuristic: new SIP message often starts with <--- or ---> in Asterisk logger
            if buf and re.match(r'^<*-{2,}>*\s*$', line.strip()) is None and re.match(r'^(<{3}|>{3})', line):
                flush()
            buf.append(line.rstrip("\n"))
    flush()

for o in msgs:
    print(json.dumps(o, ensure_ascii=False))
PY
}

emit_from_pcap() {
	local pcap="$1"
	command -v tshark >/dev/null 2>&1 || {
		echo "warn: tshark not installed — cannot extract pcap $pcap" >&2
		return 0
	}
	local filter="sip"
	[[ -n "$call_id" ]] && filter="sip.Call-ID contains \"${call_id}\""
	tshark -r "$pcap" -Y "$filter" -T fields \
		-e frame.time_epoch -e sip.Method -e sip.Status-Code \
		-e sip.Call-ID -e sip.From -e sip.To -e sip.Request-Line -e sip.CSeq -e sip.Via.branch \
		-E separator=$'\t' -E quote=n -E occurrence=f 2>/dev/null \
	| python3 - "$want_raw" <<'PY'
import json, sys
want_raw = sys.argv[1] == "1"
for line in sys.stdin:
    parts = line.rstrip("\n").split("\t")
    while len(parts) < 9:
        parts.append("")
    t, method, status, cid, frm, to, ruri, cseq, via = parts[:9]
    try:
        ts = float(t) if t else None
        t_iso = None
        if ts is not None:
            from datetime import datetime, timezone
            t_iso = datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    except Exception:
        t_iso = None
    obj = {
        "t": t_iso,
        "dir": None,
        "method": method or None,
        "status": int(status) if status.isdigit() else None,
        "call_id": cid or None,
        "from": frm or None,
        "to": to or None,
        "ruri": ruri or None,
        "cseq": cseq or None,
        "via_branch": via or None,
        "has_body": False,
        "raw": None,
        "source": "pcap",
    }
    print(json.dumps(obj, ensure_ascii=False))
PY
}

out_fd=1
tmp=""
if [[ -n "$outfile" ]]; then
	tmp=$(mktemp)
	exec >"$tmp"
fi

case "$source" in
	text)
		# live + rotated segments
		for f in "$SIP_TEXT" "$SIP_TEXT".*; do
			[[ -f "$f" ]] || continue
			[[ "$f" == *.gz ]] && continue
			emit_from_text "$f"
		done
		;;
	pcap)
		shopt -s nullglob
		for f in "$SIPLOG_DIR"/siplog_*.pcap "$SIPLOG_DIR"/siplog.pcap[0-9]*; do
			emit_from_pcap "$f"
		done
		;;
	auto)
		had=0
		for f in "$SIP_TEXT" "$SIP_TEXT".*; do
			[[ -f "$f" && -s "$f" ]] || continue
			emit_from_text "$f"
			had=1
		done
		if [[ "$had" -eq 0 ]]; then
			shopt -s nullglob
			for f in "$SIPLOG_DIR"/siplog_*.pcap "$SIPLOG_DIR"/siplog.pcap[0-9]*; do
				emit_from_pcap "$f"
			done
		fi
		;;
	*)
		echo "source must be text|pcap|auto" >&2
		exit 2
		;;
esac

if [[ -n "$outfile" ]]; then
	mv "$tmp" "$outfile"
	echo "wrote $outfile" >&2
fi
