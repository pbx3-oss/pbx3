#!/usr/bin/env bash
# Unit fixture: convert junction CoS matrices → profiles without privilege drift.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
APPLY="$ROOT/scripts/apply-sqlite-add-cos-profiles.sh"
CONVERT="$ROOT/scripts/convert-cos-profiles.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
DB="$WORKDIR/test.db"

sqlite3 "$DB" <<'SQL'
CREATE TABLE cos (
  pkey TEXT NOT NULL,
  cluster TEXT DEFAULT 'default',
  defaultopen TEXT DEFAULT 'NO',
  defaultclosed TEXT DEFAULT 'NO',
  orideopen TEXT DEFAULT 'NO',
  orideclosed TEXT DEFAULT 'NO'
);
CREATE TABLE ipphone (
  id TEXT PRIMARY KEY,
  pkey TEXT NOT NULL,
  cluster TEXT DEFAULT 'default'
);
CREATE TABLE ipphonecosopen (
  cluster TEXT,
  ipphone_pkey TEXT,
  cos_pkey TEXT,
  PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);
CREATE TABLE ipphonecosclosed (
  cluster TEXT,
  ipphone_pkey TEXT,
  cos_pkey TEXT,
  PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);

-- Rules: Intl default* + floor flags must NOT split fingerprints
INSERT INTO cos (pkey, cluster, defaultopen, defaultclosed, orideopen, orideclosed) VALUES
  ('Intl', 'tenanta', 'YES', 'YES', 'YES', 'YES'),
  ('Premium', 'tenanta', 'NO', 'YES', 'NO', 'NO'),
  ('LocalOnly', 'tenanta', 'NO', 'NO', 'NO', 'NO');

-- Phones: A+B same matrix; C different; D empty; E same as A but oride is on rule not phone
INSERT INTO ipphone (id, pkey, cluster) VALUES
  ('1', '1001', 'tenanta'),
  ('2', '1002', 'tenanta'),
  ('3', '1003', 'tenanta'),
  ('4', '1004', 'tenanta'),
  ('5', '2001', 'tenantb');

-- 1001/1002: open Intl; closed Intl+Premium  (matches default* fingerprint)
INSERT INTO ipphonecosopen VALUES ('tenanta', '1001', 'Intl');
INSERT INTO ipphonecosopen VALUES ('tenanta', '1002', 'Intl');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1001', 'Intl');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1001', 'Premium');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1002', 'Intl');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1002', 'Premium');

-- 1003: open LocalOnly; closed LocalOnly+Intl
INSERT INTO ipphonecosopen VALUES ('tenanta', '1003', 'LocalOnly');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1003', 'LocalOnly');
INSERT INTO ipphonecosclosed VALUES ('tenanta', '1003', 'Intl');

-- 1004: empty junctions → Unrestricted
-- 2001 tenantb: open Intl only
INSERT INTO ipphonecosopen VALUES ('tenantb', '2001', 'Intl');
SQL

pre_open=$(sqlite3 "$DB" "SELECT ipphone_pkey||'|'||cos_pkey FROM ipphonecosopen ORDER BY 1;")
pre_closed=$(sqlite3 "$DB" "SELECT ipphone_pkey||'|'||cos_pkey FROM ipphonecosclosed ORDER BY 1;")

bash "$APPLY" "$DB"
bash "$CONVERT" "$DB"
bash "$CONVERT" "$DB"  # idempotent

post_open=$(sqlite3 "$DB" "SELECT ipphone_pkey||'|'||cos_pkey FROM ipphonecosopen ORDER BY 1;")
post_closed=$(sqlite3 "$DB" "SELECT ipphone_pkey||'|'||cos_pkey FROM ipphonecosclosed ORDER BY 1;")
if [[ "$pre_open" != "$post_open" || "$pre_closed" != "$post_closed" ]]; then
  echo "FAIL: junction tables changed" >&2
  exit 1
fi

# tenanta: 3 profiles (shared Staff-like, LocalOnly-like, Unrestricted)
n_a=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile WHERE cluster='tenanta';")
if [[ "$n_a" -ne 3 ]]; then
  echo "FAIL: tenanta expected 3 profiles, got $n_a" >&2
  sqlite3 "$DB" "SELECT pkey, cname, is_default FROM cos_profile WHERE cluster='tenanta';" >&2
  exit 1
fi

# 1001 and 1002 share profile
same=$(sqlite3 "$DB" "SELECT count(DISTINCT cos_profile) FROM ipphone WHERE pkey IN ('1001','1002');")
if [[ "$same" -ne 1 ]]; then
  echo "FAIL: identical junctions should share one profile" >&2
  exit 1
fi

# 1003 different
diff=$(sqlite3 "$DB" "
SELECT CASE WHEN a.cos_profile = b.cos_profile THEN 1 ELSE 0 END
FROM ipphone a, ipphone b WHERE a.pkey='1001' AND b.pkey='1003';
")
if [[ "$diff" -ne 0 ]]; then
  echo "FAIL: different junctions must not share profile" >&2
  exit 1
fi

# 1004 empty → Unrestricted (no open/closed rows on profile)
u=$(sqlite3 "$DB" "SELECT cos_profile FROM ipphone WHERE pkey='1004';")
u_open=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile_open WHERE profile_pkey='$u';")
u_closed=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile_closed WHERE profile_pkey='$u';")
u_name=$(sqlite3 "$DB" "SELECT cname FROM cos_profile WHERE pkey='$u';")
if [[ "$u_open" -ne 0 || "$u_closed" -ne 0 || "$u_name" != "Unrestricted" ]]; then
  echo "FAIL: empty phone → Unrestricted empty profile (open=$u_open closed=$u_closed name=$u_name)" >&2
  exit 1
fi

# Default = default* fingerprint (Intl open / Intl+Premium closed) = 1001's profile
def=$(sqlite3 "$DB" "SELECT pkey FROM cos_profile WHERE cluster='tenanta' AND is_default='YES';")
p1001=$(sqlite3 "$DB" "SELECT cos_profile FROM ipphone WHERE pkey='1001';")
if [[ "$def" != "$p1001" ]]; then
  echo "FAIL: default should be default* fingerprint profile (def=$def p1001=$p1001)" >&2
  exit 1
fi
ndef=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile WHERE cluster='tenanta' AND is_default='YES';")
if [[ "$ndef" -ne 1 ]]; then
  echo "FAIL: exactly one default per tenant, got $ndef" >&2
  exit 1
fi

# Profile open/closed parity with 1001 junctions
prof_open=$(sqlite3 "$DB" "SELECT group_concat(cos_pkey, ',') FROM (SELECT cos_pkey FROM cos_profile_open WHERE profile_pkey='$p1001' ORDER BY cos_pkey);")
prof_closed=$(sqlite3 "$DB" "SELECT group_concat(cos_pkey, ',') FROM (SELECT cos_pkey FROM cos_profile_closed WHERE profile_pkey='$p1001' ORDER BY cos_pkey);")
if [[ "$prof_open" != "Intl" || "$prof_closed" != "Intl,Premium" ]]; then
  echo "FAIL: profile rules open=$prof_open closed=$prof_closed" >&2
  exit 1
fi

# oride* did not create an extra profile (still 3 on tenanta)
# tenantb has its own profile + default
n_b=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile WHERE cluster='tenantb';")
if [[ "$n_b" -lt 1 ]]; then
  echo "FAIL: tenantb should have ≥1 profile" >&2
  exit 1
fi
def_b=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile WHERE cluster='tenantb' AND is_default='YES';")
if [[ "$def_b" -ne 1 ]]; then
  echo "FAIL: tenantb needs one default, got $def_b" >&2
  exit 1
fi

# All phones linked
unlinked=$(sqlite3 "$DB" "SELECT count(*) FROM ipphone WHERE cos_profile IS NULL OR trim(cos_profile)='';")
if [[ "$unlinked" -ne 0 ]]; then
  echo "FAIL: $unlinked phones still lack cos_profile" >&2
  exit 1
fi

# Idempotent: second convert did not duplicate profiles
n_total=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile;")
bash "$CONVERT" "$DB"
n_total2=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile;")
if [[ "$n_total" -ne "$n_total2" ]]; then
  echo "FAIL: third convert changed profile count $n_total → $n_total2" >&2
  exit 1
fi

echo "PASS: convert-cos-profiles-test"
exit 0
