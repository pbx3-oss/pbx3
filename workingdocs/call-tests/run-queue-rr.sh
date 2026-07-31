#!/usr/bin/env bash
# Queue rrmemory rotation smoke / mixed-office queue slice.
# N sippuac UAS agents (static queue members) + dialers INVITE the soak queue pkey.
# Asterisk rrmemory advances agent selection; SIPp does not fan out.
#
# Usage:
#   ./run-queue-rr.sh start [mixed-office]   # default profile
#   ./run-queue-rr.sh stop                  # graceful drain then kill
#   ./run-queue-rr.sh stop force
#   ./run-queue-rr.sh status
#
# Requires: lab.env, soak-phones.env, soak-queue.env (provision-soak-queue.sh), sipp
# Host: sippuac (Domain) — never Peer-99 EIP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CMD="${1:-}"
ARG2="${2:-}"

for f in lab.env soak-phones.env soak-queue.env; do
  if [[ ! -f "$f" ]]; then
    echo "Missing $f" >&2
    exit 1
  fi
done
# shellcheck disable=SC1091
source ./lab.env
# shellcheck disable=SC1091
source ./soak-phones.env
# shellcheck disable=SC1091
source ./soak-queue.env

PROFILE_NAME=mixed-office
if [[ "$CMD" == "start" ]]; then
  PROFILE_NAME="${ARG2:-mixed-office}"
fi

# Defaults from mixed-office.yaml (no YAML parser required on lab host)
SOAK_CONCURRENT="${SOAK_CONCURRENT:-4}"
SOAK_HOLD_MS="${SOAK_HOLD_MS:-50000}"
SOAK_STAGGER_MS="${SOAK_STAGGER_MS:-1500}"
AGENT_N="${SOAK_QUEUE_AGENT_N:-4}"
QUEUE_DIGITS="${SOAK_QUEUE_PKEY:-2160}"

if [[ -f "profiles/${PROFILE_NAME}.env" ]]; then
  # optional override knobs alongside YAML
  # shellcheck disable=SC1091
  source "profiles/${PROFILE_NAME}.env"
fi

: "${SBC_HOST:?}"
: "${SOAK_DOMAIN:=${CATCHER_DOMAIN:?}}"
: "${LOCAL_IP:=}"
: "${PUBLIC_IP:=}"
: "${RECV_TIMEOUT:=60000}"

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?Set LOCAL_IP in lab.env}"

if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null \
    || curl -4 -fsS --max-time 5 https://icanhazip.com 2>/dev/null \
    || true)"
  PUBLIC_IP="$(echo "$PUBLIC_IP" | tr -d '[:space:]')"
fi
: "${PUBLIC_IP:?Set PUBLIC_IP in lab.env (office WAN for SIP Contact)}"

if [[ "$SOAK_CONCURRENT" -gt "$AGENT_N" ]]; then
  echo "SOAK_CONCURRENT ($SOAK_CONCURRENT) > AGENT_N ($AGENT_N) — raise agent_n or lower concurrent" >&2
  exit 1
fi

RUN_FLAG="$ROOT/notes/queue-rr.run"
UAS_PID_FILE="$ROOT/notes/queue-rr.uas.pids"
UAC_PID_FILE="$ROOT/notes/queue-rr.uac.pids"
LOG_DIR="$ROOT/notes/queue-rr"
UAS_PORT_BASE=5600
UAC_PORT_BASE=5800

mkdir -p "$LOG_DIR" notes

count_pids() {
  local f="$1" n=0 pid
  [[ -f "$f" ]] || { echo 0; return; }
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      n=$((n + 1))
    fi
  done <"$f"
  echo "$n"
}

force_kill() {
  local f pid
  for f in "$UAS_PID_FILE" "$UAC_PID_FILE"; do
    [[ -f "$f" ]] || continue
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill -TERM "$pid" 2>/dev/null || true
      # child sipp processes
      pkill -P "$pid" 2>/dev/null || true
    done <"$f"
  done
  sleep 1
  for f in "$UAS_PID_FILE" "$UAC_PID_FILE"; do
    [[ -f "$f" ]] || continue
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill -KILL "$pid" 2>/dev/null || true
      pkill -9 -P "$pid" 2>/dev/null || true
    done <"$f"
  done
  rm -f "$UAS_PID_FILE" "$UAC_PID_FILE" "$RUN_FLAG"
}

stop_rr() {
  local mode="${1:-graceful}"
  if [[ "$mode" == "force" ]]; then
    force_kill
    echo "queue-rr stopped (force). If Active Calls linger: ./clear-sbc-dialogs.sh"
    return
  fi
  rm -f "$RUN_FLAG"
  echo "queue-rr: draining dialers (BYE)…"
  local wait_s=0
  while [[ "$(count_pids "$UAC_PID_FILE")" -gt 0 && "$wait_s" -lt 90 ]]; do
    sleep 2
    wait_s=$((wait_s + 2))
  done
  if [[ "$(count_pids "$UAC_PID_FILE")" -gt 0 ]]; then
    echo "Dialers still running after ${wait_s}s — force-killing remainder." >&2
  fi
  force_kill
  echo "queue-rr stopped (graceful)."
}

status_rr() {
  local uas_n uac_n
  uas_n="$(count_pids "$UAS_PID_FILE")"
  uac_n="$(count_pids "$UAC_PID_FILE")"
  if [[ -f "$RUN_FLAG" ]]; then
    echo "queue-rr: RUNNING profile=$PROFILE_NAME queue=$QUEUE_DIGITS agents=$AGENT_N concurrent=$SOAK_CONCURRENT hold_ms=$SOAK_HOLD_MS uas=$uas_n uac=$uac_n"
  else
    echo "queue-rr: STOPPED uas=$uas_n uac=$uac_n"
  fi
}

start_uas() {
  local i="$1" user="$2" pass="$3" port="$4"
  local log="$LOG_DIR/uas-${i}.log"
  nohup bash -c "
    sipp \"$SBC_HOST\" \
      -i \"$LOCAL_IP\" -p \"$port\" \
      -sf scenarios/soak-register.xml \
      -au \"$user\" -ap \"$pass\" \
      -key domain \"$SOAK_DOMAIN\" \
      -key user \"$user\" \
      -key contact_ip \"$PUBLIC_IP\" \
      -m 1 \
      -recv_timeout \"$RECV_TIMEOUT\" \
      -timeout_error \
      -trace_err \
      -error_file \"$LOG_DIR/uas-${i}-reg-err.log\" \
      >/dev/null 2>&1 || true
    exec sipp \
      -i \"$LOCAL_IP\" -p \"$port\" \
      -sf \"$LOG_DIR/soak-answer-live.xml\" \
      -key user \"$user\" \
      -key contact_ip \"$PUBLIC_IP\" \
      -m 999999 \
      -l 1 \
      -recv_timeout 3600000 \
      -trace_err \
      -error_file \"$LOG_DIR/uas-${i}-err.log\" \
      >>\"$log\" 2>&1
  " >/dev/null 2>&1 &
  echo $! >>"$UAS_PID_FILE"
  disown $! 2>/dev/null || true
}

start_uac_loop() {
  local i="$1" user="$2" pass="$3" digits="$4" port="$5"
  local log="$LOG_DIR/uac-${i}.log"
  nohup bash -c "
    sipp \"$SBC_HOST\" \
      -i \"$LOCAL_IP\" -p \"$port\" \
      -sf scenarios/soak-register.xml \
      -au \"$user\" -ap \"$pass\" \
      -key domain \"$SOAK_DOMAIN\" \
      -key user \"$user\" \
      -key contact_ip \"$PUBLIC_IP\" \
      -m 1 \
      -recv_timeout \"$RECV_TIMEOUT\" \
      -timeout_error \
      -trace_err \
      -error_file \"$LOG_DIR/uac-${i}-reg-err.log\" \
      >/dev/null 2>&1 || true
    while [[ -f \"$RUN_FLAG\" ]]; do
      sipp \"$SBC_HOST\" \
        -i \"$LOCAL_IP\" -p \"$port\" \
        -sf \"$LOG_DIR/soak-dial-live.xml\" \
        -au \"$user\" -ap \"$pass\" \
        -key domain \"$SOAK_DOMAIN\" \
        -key user \"$user\" \
        -key digits \"$digits\" \
        -key contact_ip \"$PUBLIC_IP\" \
        -m 1 \
        -recv_timeout \"$RECV_TIMEOUT\" \
        -timeout_error \
        -trace_err \
        -error_file \"$LOG_DIR/uac-${i}-err.log\" \
        >>\"$log\" 2>&1 || true
      sleep 1
    done
  " >/dev/null 2>&1 &
  echo $! >>"$UAC_PID_FILE"
  disown $! 2>/dev/null || true
}

start_rr() {
  if [[ -f "$RUN_FLAG" ]]; then
    echo "queue-rr already running (notes/queue-rr.run). ./run-queue-rr.sh stop first." >&2
    exit 1
  fi
  if ! command -v sipp >/dev/null 2>&1; then
    echo "sipp not found" >&2
    exit 1
  fi

  rm -f "$RUN_FLAG"
  force_kill >/dev/null 2>&1 || true
  : >"$UAS_PID_FILE"
  : >"$UAC_PID_FILE"
  touch "$RUN_FLAG"

  cp scenarios/soak-answer.xml "$LOG_DIR/soak-answer-live.xml"
  sed "s/HOLD_PLACEHOLDER/${SOAK_HOLD_MS}/g" scenarios/soak-dial.xml >"$LOG_DIR/soak-dial-live.xml"

  echo "Starting queue-rr profile=${PROFILE_NAME} queue=${QUEUE_DIGITS} agents=${AGENT_N} concurrent=${SOAK_CONCURRENT} hold_ms=${SOAK_HOLD_MS} domain=${SOAK_DOMAIN}"

  local i a_user a_pass d_user d_pass
  for ((i = 0; i < AGENT_N; i++)); do
    eval "a_user=\${ANSWERER_${i}_USER:?}"
    eval "a_pass=\${ANSWERER_${i}_PASS:?}"
    start_uas "$i" "$a_user" "$a_pass" $((UAS_PORT_BASE + i))
    sleep "$(awk "BEGIN{print ${SOAK_STAGGER_MS}/1000}")"
  done

  sleep 2

  # Dialers call the queue pkey (rrmemory picks next agent)
  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    eval "d_user=\${DIALER_${i}_USER:?}"
    eval "d_pass=\${DIALER_${i}_PASS:?}"
    start_uac_loop "$i" "$d_user" "$d_pass" "$QUEUE_DIGITS" $((UAC_PORT_BASE + i))
    sleep "$(awk "BEGIN{print ${SOAK_STAGGER_MS}/1000}")"
  done

  status_rr
  echo "Logs: $LOG_DIR — on golden: asterisk -rx 'queue show ${SOAK_QUEUE_SHORTUID:-<shortuid>}'  (section name is shortuid, not pkey ${QUEUE_DIGITS})"
  echo "Stop: ./run-queue-rr.sh stop"
}

case "$CMD" in
  start) start_rr ;;
  stop) stop_rr "${ARG2:-graceful}" ;;
  status) status_rr ;;
  *)
    echo "Usage: $0 {start|stop|status} [mixed-office|force]" >&2
    exit 1
    ;;
esac
