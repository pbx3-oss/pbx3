#!/usr/bin/env bash
# Peer 99 (SIPp Catcher) — answer Magrathea Egress as fake PSTN.
#
# Usage (on 98.82.58.59):
#   ./run-peer-pstn-uas.sh start
#   ./run-peer-pstn-uas.sh stop
#   ./run-peer-pstn-uas.sh status
#
# Binds UDP 5060 (matches dr_gateways gwid 99 address). Contact = PUBLIC_IP/EIP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source ./lab.env

: "${SBC_HOST:?}"
: "${LOCAL_IP:=}"
: "${PUBLIC_IP:=}"
: "${PEER_PSTN_PORT:=5060}"

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?}"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null | tr -d '[:space:]' || true)"
fi
: "${PUBLIC_IP:?Set PUBLIC_IP to catcher EIP}"

PID_FILE="$ROOT/notes/peer-pstn-uas.pid"
LOG="$ROOT/notes/peer-pstn-uas.log"
mkdir -p notes

cmd="${1:-}"

stop_uas() {
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f 'peer-pstn-answer\.xml' 2>/dev/null || true
  fuser -k "${PEER_PSTN_PORT}/udp" 2>/dev/null || true
  echo "peer-pstn UAS stopped."
}

status_uas() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "peer-pstn UAS: RUNNING pid=$(cat "$PID_FILE") bind=$LOCAL_IP:$PEER_PSTN_PORT contact=$PUBLIC_IP"
  else
    echo "peer-pstn UAS: STOPPED"
  fi
}

start_uas() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Already running (pid $(cat "$PID_FILE")). stop first." >&2
    exit 1
  fi
  stop_uas >/dev/null 2>&1 || true
  : >"$LOG"
  echo "Starting peer-pstn UAS on $LOCAL_IP:$PEER_PSTN_PORT contact=$PUBLIC_IP (answer Magrathea Egress)"
  nohup sipp \
    -i "$LOCAL_IP" -p "$PEER_PSTN_PORT" \
    -sf scenarios/peer-pstn-answer.xml \
    -key contact_ip "$PUBLIC_IP" \
    -m 999999 \
    -l 50 \
    -recv_timeout 3600000 \
    -trace_err -error_file notes/peer-pstn-uas-err.log \
    >>"$LOG" 2>&1 &
  echo $! >"$PID_FILE"
  disown $! 2>/dev/null || true
  sleep 0.5
  status_uas
}

case "$cmd" in
  start) start_uas ;;
  stop) stop_uas ;;
  status) status_uas ;;
  *)
    echo "Usage: $0 {start|stop|status}" >&2
    exit 1
    ;;
esac
