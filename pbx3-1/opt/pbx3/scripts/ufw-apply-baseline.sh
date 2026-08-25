#!/bin/bash
# Apply PBX3 home UFW rules from declarative HoR (/etc/pbx3/firewall.allows.json)
# or bootstrap a fleet|solo baseline into that file then apply.
# Spec: workingdocs/UFW_SHOREWALL_MIGRATION.md §3–§4 / §7 / Phase 1–3.
#
# Usage (as root):
#   ufw-apply-baseline.sh              # apply existing JSON (or die if missing)
#   ufw-apply-baseline.sh fleet|solo   # bootstrap JSON if missing, then apply
#   PBX3_UFW_SBC_IPS='…' ufw-apply-baseline.sh fleet
#
# JSON HoR shape:
#   { "profile":"fleet", "rules":[
#       {"action":"allow","proto":"tcp","port":"22","from":"any","comment":"SSH"}, …
#   ]}
# UFW comments become "pbx3-managed <comment>" so re-apply can delete by marker.
# LE :80 uses a separate comment ("LE renewal (managed)") — not in this file.

set -euo pipefail

PROFILE="${1:-}"
API_ENV="${PBX3API_ENV:-/opt/pbx3api/.env}"
ALLOWS_FILE="${PBX3_UFW_ALLOWS_FILE:-/etc/pbx3/firewall.allows.json}"
MARKER_PREFIX="pbx3-managed"

die() { echo "ufw-apply-baseline: $*" >&2; exit 1; }
log() { echo "ufw-apply-baseline: $*"; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
command -v ufw >/dev/null 2>&1 || die "ufw not installed"
command -v python3 >/dev/null 2>&1 || die "python3 required for firewall.allows.json"

is_ipv4_or_cidr() {
    echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$'
}

resolve_sbc_ips() {
    local raw="" ip
    if [ -n "${PBX3_UFW_SBC_IPS:-}" ]; then
        raw="$PBX3_UFW_SBC_IPS"
    elif [ -f "$API_ENV" ]; then
        raw=$(grep -E '^[[:space:]]*PBX3_SBC_EGRESS_HOST=' "$API_ENV" 2>/dev/null \
            | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
    fi
    raw=$(echo "$raw" | tr ',;' '  ')
    SBC_IPS=""
    for ip in $raw; do
        [ -z "$ip" ] && continue
        if is_ipv4_or_cidr "$ip"; then
            SBC_IPS="$SBC_IPS $ip"
        else
            log "skip non-literal SBC host '$ip' (need IP/CIDR; set PBX3_UFW_SBC_IPS)"
        fi
    done
    SBC_IPS=$(echo "$SBC_IPS" | xargs)
}

resolve_lan_cidr() {
    if [ -n "${PBX3_UFW_LAN_CIDR:-}" ]; then
        LAN_CIDR="$PBX3_UFW_LAN_CIDR"
        is_ipv4_or_cidr "$LAN_CIDR" || die "PBX3_UFW_LAN_CIDR must be IP or CIDR (got: $LAN_CIDR)"
        return
    fi
    if [ -f /etc/pbx3/lan.cidr ]; then
        LAN_CIDR=$(tr -d '[:space:]' < /etc/pbx3/lan.cidr)
        if is_ipv4_or_cidr "$LAN_CIDR"; then
            return
        fi
    fi
    LAN_CIDR=$(ip -4 route show scope link 2>/dev/null | awk '/proto kernel/ {print $1; exit}')
    if [ -z "$LAN_CIDR" ]; then
        local addr
        addr=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}')
        [ -n "$addr" ] || die "could not detect LAN CIDR; set PBX3_UFW_LAN_CIDR or run setip"
        LAN_CIDR=$(echo "$addr" | awk -F'[./]' '{printf "%s.%s.%s.0/24\n",$1,$2,$3}')
    fi
    is_ipv4_or_cidr "$LAN_CIDR" || die "detected LAN CIDR invalid: $LAN_CIDR"
}

delete_rules_matching() {
    local needle="$1"
    local num
    while true; do
        num=$(ufw status numbered 2>/dev/null | sed -n "s/^\[\s*\([0-9][0-9]*\)\].*${needle}.*/\1/p" | head -1)
        [ -n "$num" ] || break
        ufw --force delete "$num" >/dev/null
    done
}

ensure_ssh_before_cutover() {
    if ! ufw status 2>/dev/null | grep -qE '22/tcp.*ALLOW'; then
        ufw allow 22/tcp comment "${MARKER_PREFIX} SSH" >/dev/null || true
    fi
}

stop_shorewall() {
    if [ "${PBX3_UFW_SKIP_SHOREWALL_STOP:-0}" = "1" ]; then
        log "skipping Shorewall stop (PBX3_UFW_SKIP_SHOREWALL_STOP=1)"
        return
    fi
    for svc in shorewall shorewall6; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
        fi
    done
    if [ -f /etc/default/shorewall ]; then
        sed -i 's/^startup=.*/startup=0/' /etc/default/shorewall || true
    fi
    if [ -f /etc/default/shorewall6 ]; then
        sed -i 's/^startup=.*/startup=0/' /etc/default/shorewall6 || true
    fi
    if command -v shorewall >/dev/null 2>&1; then
        shorewall clear 2>/dev/null || true
    fi
    if command -v shorewall6 >/dev/null 2>&1; then
        shorewall6 clear 2>/dev/null || true
    fi
}

# Build baseline rules JSON into ALLOWS_FILE for profile.
bootstrap_allows_file() {
    local profile="$1"
    mkdir -p "$(dirname "$ALLOWS_FILE")"
    case "$profile" in
        fleet)
            resolve_sbc_ips
            [ -n "$SBC_IPS" ] || die "fleet profile needs SBC IP(s): set PBX3_UFW_SBC_IPS or PBX3_SBC_EGRESS_HOST=IP"
            SBC_IPS="$SBC_IPS" python3 - "$ALLOWS_FILE" <<'PY'
import json, os, sys
path = sys.argv[1]
ips = os.environ.get("SBC_IPS", "").split()
rules = [
    {"action": "allow", "proto": "tcp", "port": "22", "from": "any", "comment": "SSH"},
    {"action": "allow", "proto": "tcp", "port": "44300", "from": "any", "comment": "API"},
    {"action": "allow", "proto": "udp", "port": "10000:20000", "from": "any", "comment": "RTP"},
]
for ip in ips:
    rules.append({"action": "allow", "proto": "udp", "port": "5060", "from": ip, "comment": "SIP UDP"})
    rules.append({"action": "allow", "proto": "tcp", "port": "5060", "from": ip, "comment": "SIP TCP"})
    rules.append({"action": "allow", "proto": "tcp", "port": "5061", "from": ip, "comment": "SIP TLS"})
with open(path, "w", encoding="utf-8") as f:
    json.dump({"profile": "fleet", "rules": rules}, f, indent=2)
    f.write("\n")
PY
            ;;
        solo)
            resolve_lan_cidr
            LAN_CIDR="$LAN_CIDR" PBX3_UFW_SOLO_WSS="${PBX3_UFW_SOLO_WSS:-0}" python3 - "$ALLOWS_FILE" <<'PY'
import json, os, sys
path = sys.argv[1]
lan = os.environ["LAN_CIDR"]
rules = [
    {"action": "allow", "proto": "tcp", "port": "22", "from": lan, "comment": "SSH"},
    {"action": "allow", "proto": "tcp", "port": "44300", "from": lan, "comment": "API"},
    {"action": "allow", "proto": "udp", "port": "10000:20000", "from": lan, "comment": "RTP"},
    {"action": "allow", "proto": "udp", "port": "5060", "from": lan, "comment": "SIP UDP"},
    {"action": "allow", "proto": "tcp", "port": "5060", "from": lan, "comment": "SIP TCP"},
    {"action": "allow", "proto": "tcp", "port": "5061", "from": lan, "comment": "SIP TLS"},
]
if os.environ.get("PBX3_UFW_SOLO_WSS") == "1":
    rules.append({"action": "allow", "proto": "tcp", "port": "8089", "from": lan, "comment": "WSS"})
with open(path, "w", encoding="utf-8") as f:
    json.dump({"profile": "solo", "rules": rules}, f, indent=2)
    f.write("\n")
PY
            ;;
        *) die "bootstrap profile must be fleet|solo" ;;
    esac
    log "wrote $ALLOWS_FILE (profile=$profile)"
}

apply_rule_from_json_line() {
    # stdin: one JSON object per invocation via env vars set by python driver
    local action="$1" proto="$2" port="$3" from="$4" comment="$5"
    local ufw_comment
    if [ -n "$comment" ]; then
        ufw_comment="${MARKER_PREFIX} ${comment}"
    else
        ufw_comment="${MARKER_PREFIX}"
    fi
    case "$action" in
        allow) ;;
        *) log "skip unsupported action '$action'"; return 0 ;;
    esac
    case "$proto" in
        tcp|udp|icmp|all) ;;
        *) die "invalid proto: $proto" ;;
    esac
    if [ "$proto" = "icmp" ]; then
        # UFW icmp: allow from source (port N/A)
        if [ "$from" = "any" ] || [ -z "$from" ]; then
            ufw allow proto icmp comment "$ufw_comment" >/dev/null 2>&1 || \
                ufw allow icmp comment "$ufw_comment" >/dev/null || true
        else
            ufw allow from "$from" proto icmp comment "$ufw_comment" >/dev/null || true
        fi
        return 0
    fi
    if [ "$proto" = "all" ]; then
        if [ "$from" = "any" ] || [ -z "$from" ]; then
            [ -n "$port" ] && [ "$port" != "N/A" ] && die "proto=all with port not supported"
            ufw allow from any comment "$ufw_comment" >/dev/null || true
        else
            ufw allow from "$from" comment "$ufw_comment" >/dev/null
        fi
        return 0
    fi
    [ -n "$port" ] || die "port required for proto=$proto"
    if [ "$from" = "any" ] || [ -z "$from" ]; then
        ufw allow "${port}/${proto}" comment "$ufw_comment" >/dev/null
    else
        ufw allow from "$from" to any port "$port" proto "$proto" comment "$ufw_comment" >/dev/null
    fi
}

apply_allows_file() {
    [ -f "$ALLOWS_FILE" ] || die "missing $ALLOWS_FILE (pass fleet|solo to bootstrap)"
    # Stream rules as TSV: action proto port from comment
    while IFS=$'\t' read -r action proto port from comment; do
        [ -n "$action" ] || continue
        apply_rule_from_json_line "$action" "$proto" "$port" "$from" "$comment"
    done < <(python3 - "$ALLOWS_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
rules = data.get("rules") or []
for r in rules:
    action = (r.get("action") or "allow").strip()
    proto = (r.get("proto") or "").strip().lower()
    port = (r.get("port") or "").strip()
    frm = (r.get("from") or "any").strip() or "any"
    comment = (r.get("comment") or "").replace("\t", " ").replace("\n", " ").strip()
    print("\t".join([action, proto, port, frm, comment]))
PY
)
    PROFILE_APPLIED=$(python3 - "$ALLOWS_FILE" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("profile", ""))
PY
)
    log "applied rules from $ALLOWS_FILE (profile=${PROFILE_APPLIED:-unknown})"
}

# --- main ---

if [ -n "$PROFILE" ]; then
    case "$PROFILE" in
        fleet|solo) ;;
        *) die "usage: $0 [fleet|solo]" ;;
    esac
    if [ ! -f "$ALLOWS_FILE" ]; then
        bootstrap_allows_file "$PROFILE"
    else
        log "keeping existing $ALLOWS_FILE (pass: delete file to re-bootstrap profile=$PROFILE)"
    fi
elif [ ! -f "$ALLOWS_FILE" ]; then
    die "usage: $0 fleet|solo   # first run bootstraps $ALLOWS_FILE"
fi

log "allows=$ALLOWS_FILE"
ensure_ssh_before_cutover
stop_shorewall

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw default deny routed >/dev/null 2>/dev/null || true

delete_rules_matching "$MARKER_PREFIX"
apply_allows_file

ufw --force enable >/dev/null
ufw status verbose | sed -n '1,80p'
log "done (LE :80 is managed separately by le-port80-open/close)"
exit 0
