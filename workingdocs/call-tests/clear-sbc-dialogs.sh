#!/usr/bin/env bash
# Clear stuck OpenSIPS dialogs on Magrathea (lab Active Calls litter).
# Run from operator Mac after force-stop / pack kill residue.
#
# Usage:
#   ./clear-sbc-dialogs.sh
#   SBC_SSH='ssh -i …/opensips.pem ubuntu@sbc.pbx3.com' ./clear-sbc-dialogs.sh
#
# Prefers MI dlg_end_dlg; restarts opensips if state-5 ghosts remain.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$ROOT/lab.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/lab.env"
fi

: "${SBC_SSH:=ssh -i ${HOME}/Documents/pemfiles/opensips.pem -o BatchMode=yes -o ConnectTimeout=10 ubuntu@sbc.pbx3.com}"

$SBC_SSH 'bash -s' <<'EOF'
set -euo pipefail

curl -sS -m 8 http://127.0.0.1:8888/mi -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"dlg_list","id":1}' > /tmp/dlg.json

python3 <<'PY'
import json, urllib.request
raw = open("/tmp/dlg.json").read()
i, j = raw.find("{"), raw.rfind("}")
dialogs = json.loads(raw[i : j + 1]).get("result", {}).get("Dialogs") or []
print(f"before={len(dialogs)}")
ok = fail = 0
for d in dialogs:
    p = {"jsonrpc": "2.0", "id": 1, "method": "dlg_end_dlg", "params": [d["ID"]]}
    req = urllib.request.Request(
        "http://127.0.0.1:8888/mi",
        data=json.dumps(p).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        body = urllib.request.urlopen(req, timeout=5).read().decode()
        resp = json.loads(body[body.find("{") : body.rfind("}") + 1])
        if "error" in resp:
            fail += 1
        else:
            ok += 1
    except Exception:
        fail += 1
print(f"dlg_end_dlg ok={ok} fail={fail}")
PY

sleep 1
after=$(curl -sS -m 8 http://127.0.0.1:8888/mi -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"dlg_list","id":1}' \
  | python3 -c 'import json,sys; r=sys.stdin.read(); i=r.find("{"); j=r.rfind("}"); print(len(json.loads(r[i:j+1]).get("result",{}).get("Dialogs") or []))')

echo "after_mi=$after"
if [[ "$after" != "0" ]]; then
  echo "Restarting opensips to drop in-memory dialogs…"
  sudo mysql -e "DELETE FROM opensips.dialog;" 2>/dev/null || true
  sudo systemctl restart opensips
  sleep 2
  systemctl is-active opensips
  curl -sS -m 8 http://127.0.0.1:8888/mi -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"dlg_list","id":1}' \
  | python3 -c 'import json,sys; r=sys.stdin.read(); i=r.find("{"); j=r.rfind("}"); print("post_restart="+str(len(json.loads(r[i:j+1]).get("result",{}).get("Dialogs") or [])))'
fi
EOF
