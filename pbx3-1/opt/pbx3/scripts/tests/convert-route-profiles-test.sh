#!/usr/bin/env bash
# Unit fixture: convert leaves open/close dests + dual-read profiles intact.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
APPLY="$ROOT/scripts/apply-sqlite-add-time-based-routing.sh"
CONVERT="$ROOT/scripts/convert-route-profiles.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
DB="$WORKDIR/test.db"

sqlite3 "$DB" <<'SQL'
CREATE TABLE cluster (
  pkey TEXT PRIMARY KEY,
  shortuid TEXT,
  oclo TEXT,
  routeoverride TEXT
);
CREATE TABLE dateseg (
  pkey INTEGER PRIMARY KEY,
  cluster TEXT,
  timespan TEXT,
  state TEXT
);
CREATE TABLE holiday (
  id TEXT PRIMARY KEY,
  cluster TEXT,
  route TEXT,
  stime INTEGER,
  etime INTEGER
);
CREATE TABLE inroutes (
  id TEXT PRIMARY KEY,
  pkey TEXT,
  cluster TEXT,
  openroute TEXT,
  closeroute TEXT
);
INSERT INTO cluster (pkey, shortuid, oclo) VALUES ('default', 'testtn01', 'OPEN');
INSERT INTO dateseg (pkey, cluster, timespan, state) VALUES (1, 'testtn01', '09:00-17:00', 'IDLE');
INSERT INTO holiday (id, cluster, route, stime, etime) VALUES ('h1', 'testtn01', '9000', 1, 9999999999);
INSERT INTO inroutes (id, pkey, cluster, openroute, closeroute) VALUES
  ('i1', '441924910444', 'testtn01', '1101', '9001'),
  ('i2', '441924918076', 'testtn01', '1101', '9001'),
  ('i3', '441234567890', 'testtn01', '2200', '9002');
SQL

# Capture pre-convert dest matrix
pre=$(sqlite3 "$DB" "SELECT pkey||'|'||openroute||'|'||closeroute FROM inroutes ORDER BY pkey;")

bash "$APPLY" "$DB"
bash "$CONVERT" "$DB"
bash "$CONVERT" "$DB"  # idempotent second run

post=$(sqlite3 "$DB" "SELECT pkey||'|'||openroute||'|'||closeroute FROM inroutes ORDER BY pkey;")
if [[ "$pre" != "$post" ]]; then
  echo "FAIL: open/close columns changed" >&2
  echo "pre=$pre" >&2
  echo "post=$post" >&2
  exit 1
fi

# Both DIDs with same pair share one profile
nprof=$(sqlite3 "$DB" "SELECT count(*) FROM route_profile WHERE cluster='testtn01';")
if [[ "$nprof" -ne 2 ]]; then
  echo "FAIL: expected 2 profiles for two distinct pairs, got $nprof" >&2
  exit 1
fi

linked=$(sqlite3 "$DB" "SELECT count(*) FROM inroutes WHERE route_profile IS NOT NULL AND route_profile != '';")
if [[ "$linked" -ne 3 ]]; then
  echo "FAIL: all inroutes should have route_profile, got $linked" >&2
  exit 1
fi

same=$(sqlite3 "$DB" "SELECT count(DISTINCT route_profile) FROM inroutes WHERE pkey IN ('441924910444','441924918076');")
if [[ "$same" -ne 1 ]]; then
  echo "FAIL: identical open/close pairs should share profile" >&2
  exit 1
fi

non6=$(sqlite3 "$DB" "SELECT count(*) FROM route_profile WHERE length(shortuid) != 6;")
if [[ "$non6" -ne 0 ]]; then
  echo "FAIL: all route_profile.shortuid must be 6-char product shortuids, got $non6 bad" >&2
  sqlite3 "$DB" "SELECT shortuid, length(shortuid) FROM route_profile;" >&2
  exit 1
fi

line_open=$(sqlite3 "$DB" "
SELECT l.destination FROM inroutes i
JOIN route_profile_line l ON l.profile = i.route_profile AND l.mode = 'open'
WHERE i.pkey = '441924910444';
")
line_closed=$(sqlite3 "$DB" "
SELECT l.destination FROM inroutes i
JOIN route_profile_line l ON l.profile = i.route_profile AND l.mode = 'closed'
WHERE i.pkey = '441924910444';
")
if [[ "$line_open" != "1101" || "$line_closed" != "9001" ]]; then
  echo "FAIL: profile lines open=$line_open closed=$line_closed" >&2
  exit 1
fi

mode=$(sqlite3 "$DB" "SELECT mode FROM dateseg WHERE pkey=1;")
if [[ "$mode" != "closed" ]]; then
  echo "FAIL: dateseg.mode want closed got $mode" >&2
  exit 1
fi

sched=$(sqlite3 "$DB" "SELECT sched_mode FROM cluster WHERE shortuid='testtn01';")
if [[ "$sched" != "open" ]]; then
  echo "FAIL: sched_mode want open got $sched" >&2
  exit 1
fi

fd=$(sqlite3 "$DB" "SELECT force_dest FROM holiday WHERE id='h1';")
if [[ "$fd" != "9000" ]]; then
  echo "FAIL: holiday force_dest want 9000 got $fd" >&2
  exit 1
fi

echo "PASS: convert-route-profiles-test"
exit 0
