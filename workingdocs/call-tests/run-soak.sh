#!/usr/bin/env bash
# L2 demo/soak: N paired SIPp phones (dialer↔answerer) holding concurrent calls.
#
# Usage:
#   ./run-soak.sh start [demo|busy]   # demo≈10, busy≈20 concurrent
#   ./run-soak.sh stop
#   ./run-soak.sh status
#
# Requires: lab.env, soak-phones.env (from provision-soak-phones.sh), sipp
# Intended host: extension platform VM (sippuac) — never Peer-99 EIP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CMD="${1:-}"
PROFILE_NAME="${2:-demo}"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env" >&2
  exit 1
fi
if [[ ! -f soak-phones.env ]]; then
  echo "Missing soak-phones.env — run ./provision-soak-phones.sh first" >&2
  exit 1
fi

# shellcheck disable=SC1091
source ./lab.env
# shellcheck disable=SC1091
source ./soak-phones.env

if [[ -f "profiles/${PROFILE_NAME}.env" ]]; then
  # shellcheck disable=SC1091
  source "profiles/${PROFILE_NAME}.env"
fi

: "${SBC_HOST:?}"
: "${SOAK_DOMAIN:=${CATCHER_DOMAIN:?}}"
: "${SOAK_PAIR_COUNT:?}"
: "${SOAK_CONCURRENT:=10}"
: "${SOAK_HOLD_MS:=45000}"
: "${SOAK_STAGGER_MS:=500}"
: "${RECV_TIMEOUT:=60000}"
: "${LOCAL_IP:=}"

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?Set LOCAL_IP in lab.env}"

RUN_FLAG="$ROOT/notes/soak.run"
PID_FILE="$ROOT/notes/soak.pids"
LOG_DIR="$ROOT/notes/soak"
UAS_PORT_BASE=5200
UAC_PORT_BASE=5400

mkdir -p "$LOG_DIR" notes

if [[ "$SOAK_CONCURRENT" -gt "$SOAK_PAIR_COUNT" ]]; then
  echo "SOAK_CONCURRENT ($SOAK_CONCURRENT) > SOAK_PAIR_COUNT ($SOAK_PAIR_COUNT)" >&2
  exit 1
fi

stop_soak() {
  echo "Stopping soak…"
  rm -f "$RUN_FLAG"
  if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
    done <"$PID_FILE"
    rm -f "$PID_FILE"
  fi
  # Belt-and-braces: soak-tagged SIPp only
  pkill -f 'User-Agent: pbx3-call-tests/soak' 2>/dev/null || true
  pkill -f 'pbx3-soak-' 2>/dev/null || true
  # Ports we own
  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    fuser -k $((UAS_PORT_BASE + i))/udp 2>/dev/null || true
    fuser -k $((UAC_PORT_BASE + i))/udp 2>/dev/null || true
  done
  sleep 0.5
  echo "Soak stopped."
}

status_soak() {
  local n=0
  if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        n=$((n + 1))
      fi
    done <"$PID_FILE"
  fi
  if [[ -f "$RUN_FLAG" ]]; then
    echo "soak: RUNNING flag=yes live_pids=$n concurrent_target=$SOAK_CONCURRENT hold_ms=$SOAK_HOLD_MS profile=$PROFILE_NAME"
  else
    echo "soak: STOPPED live_pids=$n"
  fi
}

start_uas() {
  local i="$1" user="$2" pass="$3" port="$4"
  local log="$LOG_DIR/uas-${i}.log"
  nohup bash -c "
    sipp \"$SBC_HOST\" \
      -i \"$LOCAL_IP\" -p \"$port\" \
      -sf scenarios/catcher-register.xml \
      -au \"$user\" -ap \"$pass\" \
      -key domain \"$SOAK_DOMAIN\" \
      -key user \"$user\" \
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
      -m 999999 \
      -l 1 \
      -recv_timeout 3600000 \
      -trace_err \
      -error_file \"$LOG_DIR/uas-${i}-err.log\" \
      >>\"$log\" 2>&1
  " >/dev/null 2>&1 &
  echo $! >>"$PID_FILE"
  disown $! 2>/dev/null || true
}

start_uac_loop() {
  local i="$1" user="$2" pass="$3" digits="$4" port="$5"
  local log="$LOG_DIR/uac-${i}.log"
  nohup bash -c "
    while [[ -f \"$RUN_FLAG\" ]]; do
      sipp \"$SBC_HOST\" \
        -i \"$LOCAL_IP\" -p \"$port\" \
        -sf \"$LOG_DIR/soak-dial-live.xml\" \
        -au \"$user\" -ap \"$pass\" \
        -key domain \"$SOAK_DOMAIN\" \
        -key user \"$user\" \
        -key digits \"$digits\" \
        -m 1 \
        -recv_timeout \"$RECV_TIMEOUT\" \
        -timeout_error \
        -trace_err \
        -error_file \"$LOG_DIR/uac-${i}-err.log\" \
        >>\"$log\" 2>&1 || true
      sleep 1
    done
  " >/dev/null 2>&1 &
  echo $! >>"$PID_FILE"
  disown $! 2>/dev/null || true
}

start_soak() {
  if [[ -f "$RUN_FLAG" ]]; then
    echo "Soak already running (notes/soak.run). ./run-soak.sh stop first." >&2
    exit 1
  fi
  if ! command -v sipp >/dev/null 2>&1; then
    echo "sipp not found" >&2
    exit 1
  fi

  stop_soak >/dev/null 2>&1 || true
  : >"$PID_FILE"
  touch "$RUN_FLAG"

  # Answerer holds then BYEs (clears SBC dialog). Dialer waits hold+slack for that BYE.
  local dial_wait_ms=$((SOAK_HOLD_MS + 20000))
  sed "s/HOLD_PLACEHOLDER/${SOAK_HOLD_MS}/g" scenarios/soak-answer.xml >"$LOG_DIR/soak-answer-live.xml"
  sed "s/HOLD_PLACEHOLDER/${dial_wait_ms}/g" scenarios/soak-dial.xml >"$LOG_DIR/soak-dial-live.xml"

  echo "Starting soak profile=${PROFILE_NAME} concurrent=${SOAK_CONCURRENT} hold_ms=${SOAK_HOLD_MS} domain=${SOAK_DOMAIN} ip=${LOCAL_IP} (UAS hangup)"

  local i d_ext d_user d_pass a_ext a_user a_pass
  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    eval "d_ext=\${DIALER_${i}_EXT:?}"
    eval "d_user=\${DIALER_${i}_USER:?}"
    eval "d_pass=\${DIALER_${i}_PASS:?}"
    eval "a_ext=\${ANSWERER_${i}_EXT:?}"
    eval "a_user=\${ANSWERER_${i}_USER:?}"
    eval "a_pass=\${ANSWERER_${i}_PASS:?}"

    start_uas "$i" "$a_user" "$a_pass" $((UAS_PORT_BASE + i))
    sleep "$(awk "BEGIN{print ${SOAK_STAGGER_MS}/1000}")"
  done

  # Let REGISTERs settle
  sleep 2

  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    eval "d_user=\${DIALER_${i}_USER:?}"
    eval "d_pass=\${DIALER_${i}_PASS:?}"
    eval "a_ext=\${ANSWERER_${i}_EXT:?}"
    start_uac_loop "$i" "$d_user" "$d_pass" "$a_ext" $((UAC_PORT_BASE + i))
    sleep "$(awk "BEGIN{print ${SOAK_STAGGER_MS}/1000}")"
  done

  status_soak
  echo "Logs: $LOG_DIR — stop with: ./run-soak.sh stop"
}

case "$CMD" in
  start) start_soak ;;
  stop) stop_soak ;;
  status) status_soak ;;
  *)
    echo "Usage: $0 {start|stop|status} [demo|busy]" >&2
    exit 1
    ;;
esac
