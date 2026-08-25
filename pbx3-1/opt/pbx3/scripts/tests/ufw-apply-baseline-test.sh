#!/usr/bin/env bash
# Offline tests for ufw-apply-baseline.sh fleet|solo JSON bootstrap (no root/ufw).
# Spec: workingdocs/UFW_SHOREWALL_MIGRATION.md F10/F11 / §4.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
APPLY="$SCRIPT_DIR/../ufw-apply-baseline.sh"
[[ -x "$APPLY" || -f "$APPLY" ]] || { echo "missing $APPLY" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

assert_from() {
  local json="$1" port="$2" proto="$3" want_from="$4"
  local got
  got=$(python3 - "$json" "$port" "$proto" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
port, proto = sys.argv[2], sys.argv[3]
for r in data["rules"]:
    if r.get("port") == port and r.get("proto") == proto:
        print(r.get("from", ""))
        break
else:
    sys.exit(2)
PY
) || fail "no rule port=$port proto=$proto in $json"
  [[ "$got" == "$want_from" ]] || fail "port=$port/$proto from want=$want_from got=$got"
}

# --- fleet ---
FLEET_JSON="$WORKDIR/fleet.allows.json"
PBX3_UFW_TEST_BOOTSTRAP=1 \
  PBX3_UFW_ALLOWS_FILE="$FLEET_JSON" \
  PBX3_UFW_SBC_IPS="203.0.113.10" \
  bash "$APPLY" fleet >/dev/null

python3 - "$FLEET_JSON" <<'PY' || fail "fleet profile"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["profile"] == "fleet", d["profile"]
print("profile", d["profile"])
PY
ok "fleet profile"

assert_from "$FLEET_JSON" "22" "tcp" "any"
assert_from "$FLEET_JSON" "44300" "tcp" "any"
assert_from "$FLEET_JSON" "10000:20000" "udp" "any"
assert_from "$FLEET_JSON" "5060" "udp" "203.0.113.10"
assert_from "$FLEET_JSON" "5060" "tcp" "203.0.113.10"
assert_from "$FLEET_JSON" "5061" "tcp" "203.0.113.10"
ok "fleet SSH/API/RTP any + SIP from SBC"

# hostname-only SBC must fail fleet bootstrap
if PBX3_UFW_TEST_BOOTSTRAP=1 \
  PBX3_UFW_ALLOWS_FILE="$WORKDIR/bad.allows.json" \
  PBX3_UFW_SBC_IPS="sbc.example.com" \
  bash "$APPLY" fleet >/dev/null 2>&1; then
  fail "fleet should die on hostname-only SBC"
fi
ok "fleet rejects hostname-only SBC"

# --- solo ---
SOLO_JSON="$WORKDIR/solo.allows.json"
LAN="192.168.42.0/24"
PBX3_UFW_TEST_BOOTSTRAP=1 \
  PBX3_UFW_ALLOWS_FILE="$SOLO_JSON" \
  PBX3_UFW_LAN_CIDR="$LAN" \
  bash "$APPLY" solo >/dev/null

python3 - "$SOLO_JSON" <<'PY' || fail "solo profile"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["profile"] == "solo", d["profile"]
PY
ok "solo profile"

assert_from "$SOLO_JSON" "22" "tcp" "$LAN"
assert_from "$SOLO_JSON" "44300" "tcp" "$LAN"
assert_from "$SOLO_JSON" "10000:20000" "udp" "$LAN"
assert_from "$SOLO_JSON" "5060" "udp" "$LAN"
assert_from "$SOLO_JSON" "5060" "tcp" "$LAN"
assert_from "$SOLO_JSON" "5061" "tcp" "$LAN"
ok "solo 22/44300/RTP/SIP from LAN"

# optional WSS
SOLO_WSS="$WORKDIR/solo-wss.allows.json"
PBX3_UFW_TEST_BOOTSTRAP=1 \
  PBX3_UFW_ALLOWS_FILE="$SOLO_WSS" \
  PBX3_UFW_LAN_CIDR="$LAN" \
  PBX3_UFW_SOLO_WSS=1 \
  bash "$APPLY" solo >/dev/null
assert_from "$SOLO_WSS" "8089" "tcp" "$LAN"
ok "solo WSS from LAN when enabled"

echo "ALL PASSED"
