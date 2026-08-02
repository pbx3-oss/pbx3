#!/bin/bash
# Bootstrap or reset the first SPA / Sanctum admin in /opt/pbx3/db/sqlite.db
#
# Create (only when users table is empty), unless --reset:
#   sudo PBX3_ADMIN_EMAIL=ops@example.com PBX3_ADMIN_PASSWORD='secret' \
#     /opt/pbx3/scripts/bootstrap-admin-user.sh
# Interactive (TTY, env unset):
#   sudo /opt/pbx3/scripts/bootstrap-admin-user.sh
#
# Reset password for existing email (or sole user):
#   sudo PBX3_ADMIN_EMAIL=admin@pbx3.com PBX3_ADMIN_PASSWORD='new' \
#     /opt/pbx3/scripts/bootstrap-admin-user.sh --reset
#
# Env:
#   PBX3_ADMIN_EMAIL (required for create / preferred for --reset)
#   PBX3_ADMIN_PASSWORD (required)
#   PBX3_ADMIN_NAME (default Admin)
#   PBX3_SQLITE path override (default /opt/pbx3/db/sqlite.db from bashconfig)

set -euo pipefail

RESET=0
DB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      DB=$1
      shift
      ;;
  esac
done

if [[ -f /opt/pbx3/scripts/bashconfig ]]; then
  # shellcheck source=/dev/null
  . /opt/pbx3/scripts/bashconfig
fi
DB="${DB:-${SYSDB:-/opt/pbx3/db/sqlite.db}}"

if [[ ! -f "$DB" ]]; then
  echo "bootstrap-admin-user: database not found: $DB" >&2
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "bootstrap-admin-user: sqlite3 required" >&2
  exit 1
fi
if ! command -v php >/dev/null 2>&1; then
  echo "bootstrap-admin-user: php required to bcrypt passwords" >&2
  exit 1
fi

ucount=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo 0)
if [[ "$RESET" != "1" && "${ucount:-0}" -gt 0 ]]; then
  echo "bootstrap-admin-user: users already present ($ucount); skip create (use --reset to change password)"
  exit 0
fi
if [[ "$RESET" == "1" && "${ucount:-0}" -eq 0 ]]; then
  echo "bootstrap-admin-user: no users to reset — will create instead"
  RESET=0
fi

email="${PBX3_ADMIN_EMAIL:-}"
pass="${PBX3_ADMIN_PASSWORD:-}"
name="${PBX3_ADMIN_NAME:-Admin}"

if [[ -z "$email" || -z "$pass" ]]; then
  if [[ -t 0 ]]; then
    echo "=== Admin SPA login (Sanctum) ===" >&2
    if [[ -z "$email" ]]; then
      printf "Admin email: " >&2
      read -r email
    fi
    if [[ -z "$pass" ]]; then
      printf "Admin password: " >&2
      # shellcheck disable=SC2162
      read -rs pass
      echo >&2
      printf "Confirm password: " >&2
      read -rs pass2
      echo >&2
      if [[ "$pass" != "$pass2" ]]; then
        echo "bootstrap-admin-user: passwords do not match" >&2
        exit 1
      fi
    fi
    if [[ -z "${PBX3_ADMIN_NAME:-}" && -t 0 ]]; then
      printf "Display name [%s]: " "$name" >&2
      read -r name_in || true
      [[ -n "${name_in:-}" ]] && name=$name_in
    fi
  else
    echo "bootstrap-admin-user: set PBX3_ADMIN_EMAIL and PBX3_ADMIN_PASSWORD (non-interactive)" >&2
    exit 1
  fi
fi

email=$(echo "$email" | tr -d '[:space:]')
# loose email shape (same idea as login validator)
if ! echo "$email" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'; then
  echo "bootstrap-admin-user: invalid email: $email" >&2
  exit 1
fi
if [[ ${#pass} -lt 8 ]]; then
  echo "bootstrap-admin-user: password must be at least 8 characters" >&2
  exit 1
fi

hash=$(php -r 'echo password_hash($argv[1], PASSWORD_BCRYPT);' "$pass")
if [[ -z "$hash" || "$hash" == "false" ]]; then
  echo "bootstrap-admin-user: password_hash failed" >&2
  exit 1
fi

sql_esc() {
  printf '%s' "$1" | sed "s/'/''/g"
}
_e=$(sql_esc "$email")
_n=$(sql_esc "$name")
_h=$(sql_esc "$hash")
_now=$(date -u +%Y-%m-%d\ %H:%M:%S)

has_col() {
  sqlite3 "$DB" "PRAGMA table_info(users);" | awk -F'|' '{print $2}' | grep -qx "$1"
}

if [[ "$RESET" == "1" ]]; then
  target_id=$(sqlite3 "$DB" "SELECT id FROM users WHERE email='$_e' LIMIT 1;")
  if [[ -z "$target_id" ]]; then
    # sole user fallback when email not found
    if [[ "$ucount" -eq 1 ]]; then
      target_id=$(sqlite3 "$DB" "SELECT id FROM users LIMIT 1;")
      echo "bootstrap-admin-user: email not found; resetting sole user id=$target_id" >&2
    else
      echo "bootstrap-admin-user: no user with email $email (and not sole-user)" >&2
      exit 1
    fi
  fi
  sqlite3 "$DB" "UPDATE users SET password='$_h', updated_at='$_now' WHERE id=$target_id;"
  out_email=$(sqlite3 "$DB" "SELECT email FROM users WHERE id=$target_id;")
  echo "bootstrap-admin-user: password reset for $out_email (id=$target_id)"
  exit 0
fi

# CREATE
cols="name,email,password,abilities,created_at,updated_at"
vals="'$_n','$_e','$_h','[\"admin\"]','$_now','$_now'"
if has_col portable; then
  cols="$cols,portable"
  vals="$vals,0"
fi
if has_col allowed_clusters; then
  cols="$cols,allowed_clusters"
  vals="$vals,NULL"
fi
if has_col cluster; then
  cols="$cols,cluster"
  vals="$vals,'default'"
fi

sqlite3 "$DB" "INSERT INTO users ($cols) VALUES ($vals);"
new_id=$(sqlite3 "$DB" "SELECT id FROM users WHERE email='$_e' LIMIT 1;")
echo "bootstrap-admin-user: created admin id=$new_id email=$email"
echo "Log in at https://<fqdn>:44300 with that email and password."
