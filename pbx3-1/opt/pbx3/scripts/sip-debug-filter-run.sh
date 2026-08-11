#!/bin/bash
# Follow Asterisk verbose raw channel → write SIP-only text (res_pjsip_logger).
# Spec: HOME_SIP_LOGGING_REQUIREMENTS.md — primary AI surface is SIP messages, not verbose noise.
set -euo pipefail
# shellcheck source=/dev/null
. /opt/pbx3/scripts/sip-debug-lib.sh

RAW="${SIP_TEXT_RAW}"
OUT="${SIP_TEXT}"
mkdir -p "$(dirname "$OUT")"
touch "$RAW" "$OUT"
chown asterisk:asterisk "$RAW" "$OUT" 2>/dev/null || true
chmod 640 "$RAW" "$OUT" 2>/dev/null || true

exec python3 - "$RAW" "$OUT" <<'PY'
import os, re, sys, time

raw_path, out_path = sys.argv[1], sys.argv[2]
hdr_re = re.compile(
    r"^\[(?P<ts>[^\]]+)\]\s+VERBOSE\[[^\]]+\]\s+res_pjsip_logger\.c:\s*(?P<rest>.*)$"
)
verb_re = re.compile(r"^\[(?P<ts>[^\]]+)\]\s+VERBOSE\[[^\]]+\]\s+")

def open_follow(path):
    f = open(path, "r", errors="replace")
    f.seek(0, os.SEEK_END)
    return f

out = open(out_path, "a", buffering=1)
raw = open_follow(raw_path)
in_msg = False
buf = []

def flush():
    global buf, in_msg
    if not buf:
        in_msg = False
        return
    text = "\n".join(buf).rstrip() + "\n\n"
    out.write(text)
    out.flush()
    buf = []
    in_msg = False

while True:
    line = raw.readline()
    if line == "":
        time.sleep(0.2)
        try:
            if raw.tell() > os.path.getsize(raw_path):
                raw.close()
                raw = open_follow(raw_path)
        except OSError:
            time.sleep(0.5)
        continue
    line = line.rstrip("\n")
    m = hdr_re.match(line)
    if m:
        if in_msg:
            flush()
        rest = m.group("rest").strip()
        ts = m.group("ts")
        buf = [f"--- {ts} {rest} ---"]
        in_msg = True
        continue
    if in_msg:
        if verb_re.match(line) and "res_pjsip_logger.c:" not in line:
            flush()
            continue
        if "res_pjsip_logger.c:" in line:
            flush()
            m2 = hdr_re.match(line)
            if m2:
                rest = m2.group("rest").strip()
                ts = m2.group("ts")
                buf = [f"--- {ts} {rest} ---"]
                in_msg = True
            continue
        buf.append(line)
PY
