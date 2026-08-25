#!/bin/bash
# Apply PBX3 home UFW baseline (fleet | solo). Idempotent rewrite of pbx3-managed rules.
# Spec: workingdocs/UFW_SHOREWALL_MIGRATION.md §3–§4 / Phase 1–2.
#
# Usage (as root):
#   ufw-apply-baseline.sh fleet
#   ufw-apply-baseline.sh solo
#   PBX3_UFW_SBC_IPS='192.168.1.85' ufw-apply-baseline.sh fleet
#   PBX3_UFW_LAN_CIDR='192.168.1.0/24' ufw-apply-baseline.sh solo
#
# Env:
#   PBX3_UFW_SBC_IPS   — space/comma-separated literal IPs/CIDRs (fleet SIP/TLS source).
#                        Else first IP-looking PBX3_SBC_EGRESS_HOST from /opt/pbx3api/.env.
#   PBX3_UFW_LAN_CIDR  — solo SIP source (default: detect from ip route /24).
#   PBX3_UFW_SKIP_SHOREWALL_STOP=1 — leave Shorewall running (debug only; F7 forbids coexistence).
#
# Order: stop Shorewall → ensure SSH allow → rewrite managed allows → defaults → enable UFW.

set -euo pipefail

PROFILE="${1:-}"
API_ENV="${PBX3API_ENV:-/opt/pbx3api/.env}"
MARKER_PREFIX="pbx3-managed"
LE_MARKER="LE renewal (managed)"

die() { echo "ufw-apply-baseline: $*" >&2; exit 1; }
log() { echo "ufw-apply-baseline: $*"; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
command -v ufw >/dev/null 2>&1 || die "ufw not installed"
[ -n "$PROFILE" ] || die "usage: $0 fleet|solo"
case "$PROFILE" in
    fleet|solo) ;;
    *) die "profile must be fleet or solo (got: $PROFILE)" ;;
esac

# --- helpers ---

is_ipv4_or_cidr() {
    # Accept a.b.c.d or a.b.c.d/nn (literal only — F10).
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
            log "skip non-literal SBC host '$ip' (need IP/CIDR for UFW; set PBX3_UFW_SBC_IPS)"
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
    # Prefer connected route on default iface; fall back to /24 of primary address.
    LAN_CIDR=$(ip -4 route show scope link 2>/dev/null | awk '/proto kernel/ {print $1; exit}')
    if [ -z "$LAN_CIDR" ]; then
        local addr
        addr=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}')
        [ -n "$addr" ] || die "could not detect LAN CIDR; set PBX3_UFW_LAN_CIDR"
        # Force /24 when only host/prefix known (appliance default — F10).
        LAN_CIDR=$(echo "$addr" | awk -F'[./]' '{printf "%s.%s.%s.0/24\n",$1,$2,$3}')
    fi
    is_ipv4_or_cidr "$LAN_CIDR" || die "detected LAN CIDR invalid: $LAN_CIDR"
}

# Delete every numbered UFW rule whose comment contains MARKER (newest-first safe: always delete first match).
delete_rules_matching() {
    local needle="$1"
    local num
    while true; do
        num=$(ufw status numbered 2>/dev/null | sed -n "s/^\[\s*\([0-9][0-9]*\)\].*${needle}.*/\1/p" | head -1)
        [ -n "$num" ] || break
        ufw --force delete "$num" >/dev/null
    done
}

ufw_allow_any() {
    local port_proto="$1"
    local comment="$2"
    ufw allow "$port_proto" comment "$comment" >/dev/null
}

ufw_allow_from() {
    local from="$1"
    local port="$2"
    local proto="$3"
    local comment="$4"
    ufw allow from "$from" to any port "$port" proto "$proto" comment "$comment" >/dev/null
}

ensure_ssh_before_cutover() {
    # Avoid stranding SSH if Shorewall stops before UFW is enabled.
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
    # Clear Shorewall chains so UFW owns netfilter (F7).
    if command -v shorewall >/dev/null 2>&1; then
        shorewall clear 2>/dev/null || true
    fi
    if command -v shorewall6 >/dev/null 2>&1; then
        shorewall6 clear 2>/dev/null || true
    fi
}

apply_common_anywhere() {
    ufw_allow_any "22/tcp" "${MARKER_PREFIX} SSH"
    ufw_allow_any "44300/tcp" "${MARKER_PREFIX} API"
    ufw_allow_any "10000:20000/udp" "${MARKER_PREFIX} RTP"
}

apply_fleet_sip() {
    local ip
    [ -n "$SBC_IPS" ] || die "fleet profile needs SBC IP(s): set PBX3_UFW_SBC_IPS or PBX3_SBC_EGRESS_HOST=IP in $API_ENV"
    for ip in $SBC_IPS; do
        ufw_allow_from "$ip" 5060 udp "${MARKER_PREFIX} SIP UDP"
        ufw_allow_from "$ip" 5060 tcp "${MARKER_PREFIX} SIP TCP"
        ufw_allow_from "$ip" 5061 tcp "${MARKER_PREFIX} SIP TLS"
    done
    log "SIP 5060/5061 allowed from:$SBC_IPS"
}

apply_solo_sip() {
    ufw_allow_from "$LAN_CIDR" 5060 udp "${MARKER_PREFIX} SIP UDP"
    ufw_allow_from "$LAN_CIDR" 5060 tcp "${MARKER_PREFIX} SIP TCP"
    ufw_allow_from "$LAN_CIDR" 5061 tcp "${MARKER_PREFIX} SIP TLS"
    # Optional instance-direct WSS (solo only — not in fleet baseline).
    if [ "${PBX3_UFW_SOLO_WSS:-0}" = "1" ]; then
        ufw_allow_any "8089/tcp" "${MARKER_PREFIX} WSS"
    fi
    log "SIP 5060/5061 allowed from LAN $LAN_CIDR"
}

# --- main ---

log "profile=$PROFILE"
ensure_ssh_before_cutover
stop_shorewall

# Defaults before enable (safe while inactive).
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw default deny routed >/dev/null 2>/dev/null || true

# Rewrite managed allows (leave LE ephemeral rule alone if present).
delete_rules_matching "$MARKER_PREFIX"
# Do not delete LE_MARKER here — le-port80-*.sh owns that lifecycle.

apply_common_anywhere

case "$PROFILE" in
    fleet)
        resolve_sbc_ips
        apply_fleet_sip
        ;;
    solo)
        resolve_lan_cidr
        apply_solo_sip
        ;;
esac

ufw --force enable >/dev/null
ufw status verbose | sed -n '1,80p'
log "done (LE :80 is managed separately by le-port80-open/close)"
exit 0
