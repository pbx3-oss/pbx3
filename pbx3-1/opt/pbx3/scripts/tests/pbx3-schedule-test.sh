#!/usr/bin/env bash
# Unit tests for pbx3-schedule.php pure functions (no DB).
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../../../.." && pwd)"
# scripts/tests -> scripts -> opt/pbx3 -> pbx3-1 -> pbx3 root? 
# Path: pbx3-1/opt/pbx3/scripts/tests/thisfile
# utilities is pbx3-1/opt/pbx3/php/utilities
SCHED="$(CDPATH= cd -- "$(dirname "$0")/../../php/utilities" && pwd)/pbx3-schedule.php"

if [[ ! -f "$SCHED" ]]; then
  echo "missing $SCHED" >&2
  exit 1
fi

php -d display_errors=1 -r '
require $argv[1];

function fail($m) { fwrite(STDERR, "FAIL: $m\n"); exit(1); }
function ok($m) { echo "ok: $m\n"; }

// Fixed now: Wed 2026-08-05 12:30 UTC — week: use local of interpretation
// Use epoch for Wed 12:30
$now = strtotime("2026-08-05 12:30:00");
if (date("D", $now) !== "Wed") {
  // still use time; day may vary timezone — use dayofweek *
}

// timespan match mid-day
$row = array("month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"09:00-17:00");
if (!pbx3_dateseg_matches($row, $now)) fail("should match 09-17 at 12:30");
ok("timespan match");

// outside
$now2 = strtotime("2026-08-05 20:00:00");
if (pbx3_dateseg_matches($row, $now2)) fail("should not match 09-17 at 20:00");
ok("timespan miss");

// *-* with dow match
$wed = strtotime("next Wednesday 12:00");
$roww = array("month"=>"*","dayofweek"=>strtolower(date("D",$wed)),"datemonth"=>"*","timespan"=>"*-*");
if (!pbx3_dateseg_matches($roww, $wed)) fail("*-* with dow");
ok("star-star with field");

// no calendar field *-* alone
$allstar = array("month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"*-*");
if (pbx3_dateseg_matches($allstar, $now)) fail("all-star *-* should not match alone");
ok("all-star *-* open");

// default mode closed
if (pbx3_dateseg_mode(array()) !== "closed") fail("default mode");
if (pbx3_dateseg_mode(array("mode"=>"LUNCH")) !== "lunch") fail("lunch mode");
ok("modes");

// priority: lunch over closed
$rows = array(
  array("pkey"=>1,"cluster"=>"t","month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"09:00-17:00","mode"=>"closed","priority"=>5),
  array("pkey"=>2,"cluster"=>"t","month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"12:00-13:00","mode"=>"lunch","priority"=>10),
);
$r = pbx3_resolve_sched_mode($rows, null, strtotime("2026-08-05 12:30:00"));
if ($r["mode"] !== "lunch" || $r["winner_pkey"] != 2) fail("priority lunch want lunch/2 got ".$r["mode"]."/".$r["winner_pkey"]);
ok("priority lunch");

// no match -> open
$r2 = pbx3_resolve_sched_mode(array(), null, $now);
if ($r2["mode"] !== "open") fail("default open");
ok("default open");

// oclo dual-write
if (pbx3_oclo_from_mode("closed") !== "CLOSED") fail("oclo closed");
if (pbx3_oclo_from_mode("lunch") !== "OPEN") fail("oclo lunch");
ok("oclo map");

// holiday dest
if (pbx3_holiday_force_dest(array("route"=>"9000")) !== "9000") fail("holiday route");
if (pbx3_holiday_force_dest(array("force_dest"=>"7777","route"=>"9000")) !== "7777") fail("force_dest wins");
ok("holiday dest");

if (!pbx3_holiday_active(array("stime"=>1,"etime"=>9999999999), 100)) fail("holiday active");
if (pbx3_holiday_active(array("stime"=>100,"etime"=>200), 50)) fail("holiday inactive");
ok("holiday active");

echo "PASS: pbx3-schedule-test\n";
' "$SCHED"
