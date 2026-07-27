#!/usr/bin/env bash
# L1 automated pack against golden catcher tenant (Mac → VIP or SIPp EC2 → VIP).
# Starts catcher UAS A (+ B for CFIM / phone-302), sets lab state per scenario, runs SIPp, restores.
#
# Usage:
#   ./run-pack.sh                       # full pack
#   ./run-pack.sh phone-302-local       # one id
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env — copy lab.env.example and set CATCHER_* / GOLDEN_SSH" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./lab.env

: "${DID_CATCHER:?}"
: "${CATCHER_PORT:=5070}"
: "${CATCHER_PORT_B:=5071}"

PACK_IDS=(in-open-ext in-cfim-local in-closed-ivr-or-dest in-queue-answer phone-302-local in-multi-tenant-a-b)
if [[ $# -gt 0 ]]; then
  PACK_IDS=("$@")
fi

mkdir -p notes
PACK_LOG="notes/pack-$(date +%Y%m%d-%H%M%S).log"
FAIL=0
CATCHER_A_PID=""
CATCHER_B_PID=""
CATCHER_PEER_PID=""
CATCHER_A_MODE="" # answer | 302
: "${CATCHER_PORT_PEER:=5072}"

log() { echo "$*" | tee -a "$PACK_LOG"; }

cleanup() {
  [[ -n "$CATCHER_A_PID" ]] && kill "$CATCHER_A_PID" 2>/dev/null || true
  [[ -n "$CATCHER_B_PID" ]] && kill "$CATCHER_B_PID" 2>/dev/null || true
  [[ -n "$CATCHER_PEER_PID" ]] && kill "$CATCHER_PEER_PID" 2>/dev/null || true
  pkill -f "scenarios/catcher-answer" 2>/dev/null || true
  # Best-effort restore open baseline
  ./lab-state.sh open >/dev/null 2>&1 || true
}
trap cleanup EXIT

start_catcher() {
  local side="$1" # A|B|PEER
  local mode="${2:-answer}" # answer|302
  local user pass port logfile uas_mode domain
  domain="${CATCHER_DOMAIN:?}"
  if [[ "$side" == "A" ]]; then
    user="$CATCHER_USER"
    pass="$CATCHER_PASS"
    port="$CATCHER_PORT"
    if [[ "$mode" == "302" ]]; then
      logfile=notes/pack-catcher-a-302.log
      uas_mode=uas-302
    else
      logfile=notes/pack-catcher-a.log
      uas_mode=uas
    fi
  elif [[ "$side" == "PEER" ]]; then
    user="${CATCHER_PEER_USER:?Set CATCHER_PEER_* in lab.env for multi-tenant}"
    pass="${CATCHER_PEER_PASS:?}"
    port="$CATCHER_PORT_PEER"
    domain="${CATCHER_PEER_DOMAIN:?}"
    logfile=notes/pack-catcher-peer.log
    uas_mode=uas
  else
    user="$CATCHER_USER_B"
    pass="$CATCHER_PASS_B"
    port="$CATCHER_PORT_B"
    logfile=notes/pack-catcher-b.log
    uas_mode=uas
  fi
  : "${user:?}"
  : "${pass:?}"

  : >"$logfile"
  (
    CATCHER_USER="$user" CATCHER_PASS="$pass" CATCHER_PORT="$port" CATCHER_DOMAIN="$domain" \
      ./run-catcher.sh "$uas_mode"
  ) >"$logfile" 2>&1 &
  local pid=$!
  local ready_pat='waiting INVITE'
  [[ "$mode" == "302" ]] && ready_pat='redirects to'
  for _ in $(seq 1 40); do
    if grep -qE "$ready_pat|waiting INVITE" "$logfile" 2>/dev/null; then
      if [[ "$mode" == "302" ]]; then
        if grep -q 'redirects to' "$logfile" 2>/dev/null; then
          echo "$pid"
          return 0
        fi
      else
        if grep -q 'waiting INVITE' "$logfile" 2>/dev/null; then
          echo "$pid"
          return 0
        fi
      fi
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "catcher $side ($mode) died — see $logfile" >&2
      cat "$logfile" >&2
      return 1
    fi
    sleep 0.25
  done
  echo "catcher $side ($mode) timeout — see $logfile" >&2
  kill "$pid" 2>/dev/null || true
  return 1
}

ensure_catcher_a() {
  local mode="$1" # answer|302
  if [[ "$CATCHER_A_MODE" == "$mode" && -n "$CATCHER_A_PID" ]] && kill -0 "$CATCHER_A_PID" 2>/dev/null; then
    return 0
  fi
  if [[ -n "$CATCHER_A_PID" ]]; then
    kill "$CATCHER_A_PID" 2>/dev/null || true
    wait "$CATCHER_A_PID" 2>/dev/null || true
    CATCHER_A_PID=""
  fi
  pkill -f "scenarios/catcher-answer.*-p ${CATCHER_PORT}" 2>/dev/null || true
  sleep 0.3
  log "Starting catcher A mode=${mode} (${CATCHER_USER} :${CATCHER_PORT})"
  CATCHER_A_PID="$(start_catcher A "$mode")"
  CATCHER_A_MODE="$mode"
}

load_peer_env() {
  # Prefer lab.env; else pull from golden lab file (no secrets in git).
  if [[ -n "${CATCHER_PEER_USER:-}" && -n "${CATCHER_PEER_PASS:-}" && -n "${CATCHER_PEER_DOMAIN:-}" ]]; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2086
  if ! $GOLDEN_SSH 'test -f /tmp/sipp-peer-catcher.env && cat /tmp/sipp-peer-catcher.env' >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "CATCHER_PEER_* unset and golden /tmp/sipp-peer-catcher.env missing" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  source "$tmp"
  rm -f "$tmp"
  CATCHER_PEER_DOMAIN="${CATCHER_PEER_DOMAIN:-${PEER_DOMAIN:-}}"
  CATCHER_PEER_USER="${CATCHER_PEER_USER:-${PEER_USER:-}}"
  CATCHER_PEER_PASS="${CATCHER_PEER_PASS:-${PEER_PASS:-}}"
  : "${CATCHER_PEER_DOMAIN:?}"
  : "${CATCHER_PEER_USER:?}"
  : "${CATCHER_PEER_PASS:?}"
}

ensure_catcher_peer() {
  if [[ -n "$CATCHER_PEER_PID" ]] && kill -0 "$CATCHER_PEER_PID" 2>/dev/null; then
    return 0
  fi
  load_peer_env
  log "Starting catcher PEER (${CATCHER_PEER_USER}@${CATCHER_PEER_DOMAIN} :${CATCHER_PORT_PEER})"
  CATCHER_PEER_PID="$(start_catcher PEER answer)"
}

need_b=0
need_peer=0
for id in "${PACK_IDS[@]}"; do
  case "$id" in
    in-cfim-local|phone-302-local) need_b=1 ;;
    in-multi-tenant-a-b) need_peer=1 ;;
  esac
done

log "=== L1 pack start $(date -u +%Y-%m-%dT%H:%M:%SZ) ids=${PACK_IDS[*]} ==="

# Default A = answer; phone-302 switches mid-pack via ensure_catcher_a
ensure_catcher_a answer

if [[ "$need_b" -eq 1 ]]; then
  log "Starting catcher B (${CATCHER_USER_B} :${CATCHER_PORT_B})"
  CATCHER_B_PID="$(start_catcher B answer)"
fi

if [[ "$need_peer" -eq 1 ]]; then
  ensure_catcher_peer
fi

for id in "${PACK_IDS[@]}"; do
  log ""
  log "--- $id ---"
  case "$id" in
    in-open-ext)
      ensure_catcher_a answer
      ./lab-state.sh open | tee -a "$PACK_LOG"
      ;;
    in-cfim-local)
      ensure_catcher_a answer
      ./lab-state.sh cfim | tee -a "$PACK_LOG"
      ;;
    in-closed-ivr-or-dest|feat-master-closed)
      ensure_catcher_a answer
      ./lab-state.sh closed | tee -a "$PACK_LOG"
      ;;
    in-queue-answer)
      ensure_catcher_a answer
      ./lab-state.sh queue | tee -a "$PACK_LOG"
      ;;
    phone-302-local)
      ensure_catcher_a 302
      ./lab-state.sh open | tee -a "$PACK_LOG"
      ;;
    in-multi-tenant-a-b)
      ensure_catcher_a answer
      ensure_catcher_peer
      ./lab-state.sh open | tee -a "$PACK_LOG"
      CATCHER_PEER_USER="$CATCHER_PEER_USER" CATCHER_PEER_DOMAIN="$CATCHER_PEER_DOMAIN" \
        ./lab-state.sh multitenant | tee -a "$PACK_LOG"
      ;;
    *)
      log "SKIP unknown id $id"
      continue
      ;;
  esac

  if ./run-sipp.sh "$id" catcher >>"$PACK_LOG" 2>&1; then
    log "PASS $id"
  else
    log "FAIL $id (see $PACK_LOG and notes/${id}-*.log)"
    FAIL=1
  fi
done

log ""
if [[ "$FAIL" -eq 0 ]]; then
  log "=== PACK GREEN ==="
else
  log "=== PACK FAILED ==="
fi
exit "$FAIL"
