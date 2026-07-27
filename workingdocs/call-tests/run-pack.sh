#!/usr/bin/env bash
# L1 automated pack against golden catcher tenant (Mac → VIP).
# Starts catcher UAS A (+ B for CFIM), sets lab state per scenario, runs SIPp, restores.
#
# Usage:
#   ./run-pack.sh              # full pack
#   ./run-pack.sh in-open-ext  # one id
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

PACK_IDS=(in-open-ext in-cfim-local in-closed-ivr-or-dest in-queue-answer)
if [[ $# -gt 0 ]]; then
  PACK_IDS=("$@")
fi

mkdir -p notes
PACK_LOG="notes/pack-$(date +%Y%m%d-%H%M%S).log"
FAIL=0
CATCHER_A_PID=""
CATCHER_B_PID=""

log() { echo "$*" | tee -a "$PACK_LOG"; }

cleanup() {
  [[ -n "$CATCHER_A_PID" ]] && kill "$CATCHER_A_PID" 2>/dev/null || true
  [[ -n "$CATCHER_B_PID" ]] && kill "$CATCHER_B_PID" 2>/dev/null || true
  pkill -f "scenarios/catcher-answer.xml" 2>/dev/null || true
  # Best-effort restore open baseline
  ./lab-state.sh open >/dev/null 2>&1 || true
}
trap cleanup EXIT

start_catcher() {
  local side="$1" # A|B
  local user pass port logfile
  if [[ "$side" == "A" ]]; then
    user="$CATCHER_USER"
    pass="$CATCHER_PASS"
    port="$CATCHER_PORT"
    logfile=notes/pack-catcher-a.log
  else
    user="$CATCHER_USER_B"
    pass="$CATCHER_PASS_B"
    port="$CATCHER_PORT_B"
    logfile=notes/pack-catcher-b.log
  fi
  : "${user:?}"
  : "${pass:?}"

  (
    CATCHER_USER="$user" CATCHER_PASS="$pass" CATCHER_PORT="$port" \
      ./run-catcher.sh uas
  ) >"$logfile" 2>&1 &
  local pid=$!
  for _ in $(seq 1 40); do
    if grep -q 'waiting INVITE' "$logfile" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "catcher $side died — see $logfile" >&2
      cat "$logfile" >&2
      return 1
    fi
    sleep 0.25
  done
  echo "catcher $side timeout waiting for REGISTER — see $logfile" >&2
  kill "$pid" 2>/dev/null || true
  return 1
}

need_b=0
for id in "${PACK_IDS[@]}"; do
  [[ "$id" == "in-cfim-local" ]] && need_b=1
done

log "=== L1 pack start $(date -u +%Y-%m-%dT%H:%M:%SZ) ids=${PACK_IDS[*]} ==="
log "Starting catcher A (${CATCHER_USER} :${CATCHER_PORT})"
CATCHER_A_PID="$(start_catcher A)"
if [[ "$need_b" -eq 1 ]]; then
  log "Starting catcher B (${CATCHER_USER_B} :${CATCHER_PORT_B})"
  CATCHER_B_PID="$(start_catcher B)"
fi

for id in "${PACK_IDS[@]}"; do
  log ""
  log "--- $id ---"
  case "$id" in
    in-open-ext) ./lab-state.sh open | tee -a "$PACK_LOG" ;;
    in-cfim-local) ./lab-state.sh cfim | tee -a "$PACK_LOG" ;;
    in-closed-ivr-or-dest|feat-master-closed) ./lab-state.sh closed | tee -a "$PACK_LOG" ;;
    in-queue-answer) ./lab-state.sh queue | tee -a "$PACK_LOG" ;;
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
