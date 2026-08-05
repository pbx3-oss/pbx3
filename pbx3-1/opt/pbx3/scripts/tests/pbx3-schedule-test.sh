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

// site TZ helper: set from a temp file (do not depend on host /etc/timezone)
$tzfile = sys_get_temp_dir() . "/pbx3-sched-tz-test-" . getmypid();
file_put_contents($tzfile, "America/New_York\n");
$got = pbx3_schedule_use_site_timezone($tzfile);
@unlink($tzfile);
if ($got !== "America/New_York") fail("site tz want America/New_York got $got");
if (date_default_timezone_get() !== "America/New_York") fail("date_default_timezone not set");
ok("site timezone");

// Half-open [start, end): abutting overnight + open at 08:30 / 20:00
date_default_timezone_set("UTC");
$open = array("month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"08:30-16:30","mode"=>"open","priority"=>10,"pkey"=>10);
$eve = array("month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"16:30-20:00","mode"=>"evening","priority"=>15,"pkey"=>11);
$night = array("month"=>"*","dayofweek"=>"*","datemonth"=>"*","timespan"=>"20:00-08:30","mode"=>"closed","priority"=>25,"pkey"=>12);
$t0830 = strtotime("2026-08-05 08:30:00");
$t0829 = strtotime("2026-08-05 08:29:00");
$t2000 = strtotime("2026-08-05 20:00:00");
$t1959 = strtotime("2026-08-05 19:59:00");
if (!pbx3_dateseg_matches($open, $t0830)) fail("open must include 08:30");
if (pbx3_dateseg_matches($night, $t0830)) fail("overnight must exclude 08:30");
if (!pbx3_dateseg_matches($night, $t0829)) fail("overnight must include 08:29");
if (!pbx3_dateseg_matches($night, $t2000)) fail("overnight must include 20:00");
if (pbx3_dateseg_matches($eve, $t2000)) fail("evening must exclude 20:00");
if (!pbx3_dateseg_matches($eve, $t1959)) fail("evening must include 19:59");
$r3 = pbx3_resolve_sched_mode(array($open, $eve, $night), null, $t0830);
if ($r3["mode"] !== "open") fail("at 08:30 want open got ".$r3["mode"]);
$r4 = pbx3_resolve_sched_mode(array($open, $eve, $night), null, $t2000);
if ($r4["mode"] !== "closed") fail("at 20:00 want closed got ".$r4["mode"]);
ok("half-open abut");

echo "PASS: pbx3-schedule-test\n";
' "$SCHED"
