#!/usr/bin/env bash
# L2 demo/soak: N paired SIPp phones (dialer↔answerer) holding concurrent calls.
#
# Usage:
#   ./run-soak.sh start [demo|busy]   # demo≈10, busy≈20 concurrent
#   ./run-soak.sh stop                # graceful: drain hold+BYE, kill, Expires:0 REGISTER
#   ./run-soak.sh stop force          # immediate kill + Expires:0 (may leave SBC Active Calls)
#   ./run-soak.sh status
#
# Requires: lab.env, soak-phones.env (from provision-soak-phones.sh), sipp
# Intended host: extension platform VM (sippuac) — never Peer-99 EIP.
#
# Stop always clears Magrathea usrloc for the soak Contacts (soak-unregister).
# Otherwise answerer bindings linger on UAS ports (5200+) and queue-rr (same
# phones, different ports historically) black-holes agent INVITEs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CMD="${1:-}"
ARG2="${2:-}"

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

PROFILE_NAME=demo
if [[ "$CMD" == "start" ]]; then
  PROFILE_NAME="${ARG2:-demo}"
fi
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
: "${PUBLIC_IP:=}"

if [[ -z "$LOCAL_IP" ]]; then
  LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
: "${LOCAL_IP:?Set LOCAL_IP in lab.env}"

# Contact must be office WAN (like a real NAT phone). Private guest IP leaves
# Asterisk→answerer dialogs stuck state-3 (ACK never matched) on Magrathea.
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null \
    || curl -4 -fsS --max-time 5 https://icanhazip.com 2>/dev/null \
    || true)"
  PUBLIC_IP="$(echo "$PUBLIC_IP" | tr -d '[:space:]')"
fi
: "${PUBLIC_IP:?Set PUBLIC_IP in lab.env (office WAN for SIP Contact)}"

RUN_FLAG="$ROOT/notes/soak.run"
UAS_PID_FILE="$ROOT/notes/soak.uas.pids"
UAC_PID_FILE="$ROOT/notes/soak.uac.pids"
LEGACY_PID_FILE="$ROOT/notes/soak.pids"
LOG_DIR="$ROOT/notes/soak"
UAS_PORT_BASE=5200
UAC_PORT_BASE=5400

mkdir -p "$LOG_DIR" notes

if [[ "$SOAK_CONCURRENT" -gt "$SOAK_PAIR_COUNT" ]]; then
  echo "SOAK_CONCURRENT ($SOAK_CONCURRENT) > SOAK_PAIR_COUNT ($SOAK_PAIR_COUNT)" >&2
  exit 1
fi

pids_alive() {
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

dial_sipp_alive() {
  # In-flight soak-dial SIPp (parent bash may still be up waiting on it)
  pgrep -f 'soak-dial-live\.xml' >/dev/null 2>&1
}

force_kill_soak() {
  local pid i
  for f in "$UAS_PID_FILE" "$UAC_PID_FILE" "$LEGACY_PID_FILE"; do
    if [[ -f "$f" ]]; then
      while read -r pid; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
        # Child SIPp under nohup bash
        pkill -P "$pid" 2>/dev/null || true
      done <"$f"
      rm -f "$f"
    fi
  done
  pkill -f 'User-Agent: pbx3-call-tests/soak' 2>/dev/null || true
  pkill -f 'pbx3-soak-' 2>/dev/null || true
  pkill -f 'soak-dial-live\.xml' 2>/dev/null || true
  pkill -f 'soak-answer-live\.xml' 2>/dev/null || true
  pkill -f 'soak-unregister\.xml' 2>/dev/null || true
  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    fuser -k $((UAS_PORT_BASE + i))/udp 2>/dev/null || true
    fuser -k $((UAC_PORT_BASE + i))/udp 2>/dev/null || true
  done
  sleep 0.5
}

# Expires:0 for one Contact. Port must match the Contact we registered.
unregister_phone() {
  local user="$1" pass="$2" port="$3" label="${4:-}"
  local err="$LOG_DIR/unreg-${port}.err"
  if ! sipp "$SBC_HOST" \
    -i "$LOCAL_IP" -p "$port" \
    -sf scenarios/soak-unregister.xml \
    -au "$user" -ap "$pass" \
    -key domain "$SOAK_DOMAIN" \
    -key user "$user" \
    -key contact_ip "$PUBLIC_IP" \
    -m 1 \
    -recv_timeout 15000 \
    -timeout_error \
    -trace_err \
    -error_file "$err" \
    >/dev/null 2>&1; then
    echo "  warn: unregister ${label:-$user} :${port} failed (see $err)" >&2
    return 1
  fi
  return 0
}

# Clear Magrathea bindings for this soak's dialers+answerers (ports free).
unregister_soak_bindings() {
  local i d_user d_pass a_user a_pass
  echo "Clearing Magrathea REGISTERs (Expires:0) for ${SOAK_CONCURRENT} pairs…"
  mkdir -p "$LOG_DIR"
  for ((i = 0; i < SOAK_CONCURRENT; i++)); do
    eval "a_user=\${ANSWERER_${i}_USER:?}"
    eval "a_pass=\${ANSWERER_${i}_PASS:?}"
    eval "d_user=\${DIALER_${i}_USER:?}"
    eval "d_pass=\${DIALER_${i}_PASS:?}"
    (
      unregister_phone "$a_user" "$a_pass" $((UAS_PORT_BASE + i)) "answerer-$i" || true
      # Legacy queue-rr bases (pre-align) — ignore failures
      unregister_phone "$a_user" "$a_pass" $((5600 + i)) "answerer-$i-legacy" || true
      unregister_phone "$d_user" "$d_pass" $((UAC_PORT_BASE + i)) "dialer-$i" || true
      unregister_phone "$d_user" "$d_pass" $((5800 + i)) "dialer-$i-legacy" || true
    ) &
    # Cap fan-out so Magrathea auth isn't stampeded
    if (((i + 1) % 4 == 0)); then
      wait || true
    fi
  done
  wait || true
  echo "Unregister pass finished (warnings above if any)."
}

stop_soak() {
  local mode="${1:-graceful}"

  if [[ "$mode" == "force" ]]; then
    echo "Force-stopping soak (no BYE drain — may leave SBC Active Calls)…"
    rm -f "$RUN_FLAG"
    force_kill_soak
    unregister_soak_bindings || true
    echo "Soak stopped (force). If Active Calls linger: ./clear-sbc-dialogs.sh"
    return
  fi

  local uac_n uas_n
  uac_n="$(pids_alive "$UAC_PID_FILE")"
  uas_n="$(pids_alive "$UAS_PID_FILE")"
  if [[ ! -f "$RUN_FLAG" && "$uac_n" -eq 0 && "$uas_n" -eq 0 ]] && ! dial_sipp_alive; then
    # Stale port/pid cleanup only — still clear lingering Contacts
    force_kill_soak >/dev/null 2>&1 || true
    unregister_soak_bindings || true
    echo "Soak already stopped (bindings cleared)."
    return
  fi

  echo "Stopping soak (graceful)…"
  # Drop run flag so UAC loops exit after the current hold+BYE finishes.
  rm -f "$RUN_FLAG"

  local wait_s=$((SOAK_HOLD_MS / 1000 + 30))
  echo "Waiting up to ${wait_s}s for dialers to finish hold+BYE…"
  local deadline now
  deadline=$(($(date +%s) + wait_s))
  while true; do
    now=$(date +%s)
    uac_n="$(pids_alive "$UAC_PID_FILE")"
    if [[ "$uac_n" -eq 0 ]] && ! dial_sipp_alive; then
      echo "Dialers drained."
      break
    fi
    if ((now >= deadline)); then
      echo "Dialers still running after ${wait_s}s — force-killing remainder (may leave SBC dialogs)." >&2
      break
    fi
    sleep 1
  done

  # Answerers should have received BYE; tear them down, then drop usrloc.
  force_kill_soak
  unregister_soak_bindings || true
  echo "Soak stopped."
}

status_soak() {
  local uas_n uac_n
  uas_n="$(pids_alive "$UAS_PID_FILE")"
  uac_n="$(pids_alive "$UAC_PID_FILE")"
  # Legacy combined file
  if [[ -f "$LEGACY_PID_FILE" ]]; then
    local leg
    leg="$(pids_alive "$LEGACY_PID_FILE")"
    if [[ "$leg" -gt 0 && "$uas_n" -eq 0 && "$uac_n" -eq 0 ]]; then
      uas_n="$leg"
    fi
  fi
  if [[ -f "$RUN_FLAG" ]]; then
    echo "soak: RUNNING flag=yes uas_pids=$uas_n uac_pids=$uac_n concurrent_target=$SOAK_CONCURRENT hold_ms=$SOAK_HOLD_MS profile=$PROFILE_NAME"
  else
    echo "soak: STOPPED uas_pids=$uas_n uac_pids=$uac_n"
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
  # REGISTER once, then INVITE loop — re-REGISTER every call floods Asterisk
  # (max_contacts=1) especially when Contact flips private→public.
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

start_soak() {
  if [[ -f "$RUN_FLAG" ]]; then
    echo "Soak already running (notes/soak.run). ./run-soak.sh stop first." >&2
    exit 1
  fi
  if ! command -v sipp >/dev/null 2>&1; then
    echo "sipp not found" >&2
    exit 1
  fi

  # Immediate cleanup of any leftover processes (do not drain on start)
  rm -f "$RUN_FLAG"
  force_kill_soak >/dev/null 2>&1 || true
  : >"$UAS_PID_FILE"
  : >"$UAC_PID_FILE"
  rm -f "$LEGACY_PID_FILE"
  # Drop stale Contacts from a prior unclean stop before we re-REGISTER
  unregister_soak_bindings || true
  touch "$RUN_FLAG"

  # Dialer holds then BYEs on Record-Route path (clears SBC dialog). Answerer waits for BYE.
  cp scenarios/soak-answer.xml "$LOG_DIR/soak-answer-live.xml"
  sed "s/HOLD_PLACEHOLDER/${SOAK_HOLD_MS}/g" scenarios/soak-dial.xml >"$LOG_DIR/soak-dial-live.xml"

  echo "Starting soak profile=${PROFILE_NAME} concurrent=${SOAK_CONCURRENT} hold_ms=${SOAK_HOLD_MS} domain=${SOAK_DOMAIN} bind=${LOCAL_IP} contact=${PUBLIC_IP} (UAC hangup)"

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
  echo "Logs: $LOG_DIR — stop with: ./run-soak.sh stop  (or: stop force)"
}

case "$CMD" in
  start) start_soak ;;
  stop) stop_soak "${ARG2:-graceful}" ;;
  status) status_soak ;;
  *)
    echo "Usage: $0 {start|stop|status} [demo|busy|force]" >&2
    exit 1
    ;;
esac
