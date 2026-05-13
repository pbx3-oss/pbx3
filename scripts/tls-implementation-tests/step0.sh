#!/usr/bin/env bash
# Step 0 — TLS_IMPLEMENTATION_STEPS.md (prerequisites / globals / default tenant / tenant fqdn)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PBX3_ROOT="${PBX3_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PBX3API_ROOT="${PBX3API_ROOT:-$PBX3_ROOT/../pbx3api}"
PBX_SQLITE="${PBX_SQLITE:-/opt/pbx3/db/sqlite.db}"

echo "=== Step 0: prerequisites (TLS Option A) ==="
echo "PBX3_ROOT=$PBX3_ROOT"
echo "PBX_SQLITE=$PBX_SQLITE"

if [[ ! -r "$PBX_SQLITE" ]]; then
	tls_skip "SQLite not readable ($PBX_SQLITE) — set PBX_SQLITE or run on PBX host"
else
	dom=$(tls_sql "$PBX_SQLITE" "SELECT COALESCE(domain,'') FROM globals LIMIT 1;")
	fq=$(tls_sql "$PBX_SQLITE" "SELECT COALESCE(fqdn,'') FROM globals LIMIT 1;")
	fi=$(tls_sql "$PBX_SQLITE" "SELECT COALESCE(fqdninspect,'') FROM globals LIMIT 1;")
	if [[ -n "$dom" ]]; then tls_pass "globals.domain is set ($dom)"; else tls_fail "globals.domain empty"; fi
	if [[ -n "$fq" ]]; then tls_pass "globals.fqdn is set ($fq)"; else tls_fail "globals.fqdn empty"; fi
	if [[ "$fi" == "YES" || "$fi" == "NO" || "$fi" == "" ]]; then tls_pass "globals.fqdninspect readable ($fi)"; else tls_fail "globals.fqdninspect unexpected: $fi"; fi

	def_fq=$(tls_sql "$PBX_SQLITE" "SELECT COALESCE(fqdn,'') FROM cluster WHERE pkey='default' LIMIT 1;")
	def_dm=$(tls_sql "$PBX_SQLITE" "SELECT COALESCE(domain,'') FROM cluster WHERE pkey='default' LIMIT 1;")
	if [[ -n "$def_fq" || -n "$def_dm" ]]; then
		tls_pass "default tenant row present (fqdn=$def_fq domain=$def_dm)"
		if [[ -n "$fq" && -n "$def_fq" && "$fq" == "$def_fq" ]]; then
			tls_pass "default tenant fqdn matches globals.fqdn"
		elif [[ -n "$fq" && -n "$def_fq" ]]; then
			tls_fail "default tenant fqdn ($def_fq) != globals.fqdn ($fq) — run installer UPDATE or manual SQL"
		fi
	else
		tls_skip "no cluster pkey=default (empty DB or pre-bootstrap)"
	fi
fi

PBX3API_BASE="${PBX3API_BASE:-}"
PBX3API_TOKEN="${PBX3API_TOKEN:-}"
if [[ -z "$PBX3API_BASE" ]]; then
	tls_skip "PBX3API_BASE unset — skipping HTTP checks"
elif ! tls_need_cmd curl; then
	tls_skip "curl missing — skipping HTTP checks"
else
	api="$PBX3API_BASE"
	[[ "$api" == */ ]] && api="${api%/}"
	url="$api/api/sysglobals"
	out=$(tls_curl_json "$url" "$PBX3API_TOKEN" 2>/dev/null) || out=""
	if [[ -n "$out" ]]; then
		if tls_json_has_key "$out" domain; then tls_pass "GET sysglobals includes domain"; else tls_fail "GET sysglobals missing domain key"; fi
		if tls_json_has_key "$out" fqdninspect; then tls_pass "GET sysglobals includes fqdninspect (Step 0.3)"; else tls_fail "GET sysglobals missing fqdninspect"; fi
		if tls_json_has_key "$out" fqdn; then tls_pass "GET sysglobals includes fqdn"; else tls_fail "GET sysglobals missing fqdn"; fi
		# 0.1: PUT must not change domain (not in updateable); send minimal valid body + poison domain
		dom_before=$(echo "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('domain')or'')")
		if [[ -n "$PBX3API_TOKEN" && -n "$dom_before" ]]; then
			ab=$(echo "$out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('abstimeout'))")
			body=$(python3 -c "import json; print(json.dumps({'abstimeout':ab,'domain':'__should_not_apply__.invalid'}))")
			out2=$(curl -sS -w "\n%{http_code}" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
				${PBX3API_TOKEN:+-H "Authorization: Bearer $PBX3API_TOKEN"} \
				-d "$body" "$url" || true)
			code=$(echo "$out2" | tail -n1)
			json=$(echo "$out2" | sed '$d')
			if [[ "$code" == "200" ]]; then
				dom_after=$(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('domain')or'')")
				if [[ "$dom_before" == "$dom_after" ]]; then
					tls_pass "PUT sysglobals did not change domain (0.1 readonly)"
				else
					tls_fail "PUT sysglobals changed domain: before=$dom_before after=$dom_after"
				fi
			else
				tls_skip "PUT sysglobals returned HTTP $code (check token / CSRF / route)"
			fi
		fi
	else
		tls_skip "GET sysglobals failed or empty ($url) — set PBX3API_TOKEN if auth required"
	fi

	# 0.4 tenant fqdn immutability on default tenant
	turl="$api/api/tenants/default"
	tout=$(tls_curl_json "$turl" "$PBX3API_TOKEN" 2>/dev/null) || tout=""
	if [[ -n "$tout" ]]; then
		fq_before=$(echo "$tout" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fqdn')or'')")
		if [[ -n "$fq_before" && -n "$PBX3API_TOKEN" ]]; then
			body2='{"fqdn":"__immutable_test__.example.com"}'
			out3=$(curl -sS -w "\n%{http_code}" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
				-H "Authorization: Bearer $PBX3API_TOKEN" -d "$body2" "$turl" || true)
			code3=$(echo "$out3" | tail -n1)
			json3=$(echo "$out3" | sed '$d')
			if [[ "$code3" == "200" ]]; then
				fq_after=$(echo "$json3" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fqdn')or'')")
				if [[ "$fq_before" == "$fq_after" ]]; then
					tls_pass "PUT tenant did not change fqdn when only fqdn sent (0.4 immutable)"
				else
					tls_fail "tenant fqdn changed: $fq_before -> $fq_after"
				fi
			else
				tls_skip "PUT tenants/default returned HTTP $code3"
			fi
		else
			tls_skip "default tenant fqdn empty or no token — skip immutability PUT"
		fi
	else
		tls_skip "GET tenants/default empty or failed"
	fi
fi

# Source: SysglobalController should list fqdninspect for PUT (Step 0.3)
if [[ -f "$PBX3API_ROOT/app/Http/Controllers/SysglobalController.php" ]]; then
	if grep -q "'fqdninspect'" "$PBX3API_ROOT/app/Http/Controllers/SysglobalController.php"; then
		tls_pass "SysglobalController includes fqdninspect in update rules"
	else
		tls_fail "SysglobalController missing fqdninspect in update rules"
	fi
else
	tls_skip "pbx3api repo not at PBX3API_ROOT=$PBX3API_ROOT"
fi

exit "${TLS_TEST_FAILED:-0}"
