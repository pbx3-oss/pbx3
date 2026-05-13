# Shared helpers for TLS implementation step tests.
# shellcheck shell=bash
# Source from each step*.sh:  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TLS_TEST_FAILED=0

tls_pass() { echo "[PASS] $*"; }
tls_fail() { echo "[FAIL] $*" >&2; TLS_TEST_FAILED=1; }
tls_skip() { echo "[SKIP] $*"; }

tls_need_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# Run sqlite3 against PBX_SQLITE; print single cell or empty on error.
tls_sql() {
	local db="$1"
	shift
	sqlite3 "$db" "$@" 2>/dev/null || true
}

# Fetch JSON URL with optional Bearer token; write body to stdout.
tls_curl_json() {
	local url="$1"
	local token="${2:-}"
	if [[ -n "$token" ]]; then
		curl -sS -f -H "Accept: application/json" -H "Authorization: Bearer ${token}" "$url" || return 1
	else
		curl -sS -f -H "Accept: application/json" "$url" || return 1
	fi
}

tls_json_has_key() {
	local json="$1"
	local key="$2"
	if tls_need_cmd jq; then
		echo "$json" | jq -e "has(\"$key\")" >/dev/null 2>&1
		return $?
	fi
	python3 -c "import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if \"$key\" in d else 1)" <<<"$json" 2>/dev/null
}
