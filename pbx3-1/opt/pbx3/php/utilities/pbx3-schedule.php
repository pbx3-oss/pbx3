<?php
/**
 * Pure schedule evaluation helpers for pbx3timer (day-parts / time-based routing).
 * Injectable $now for unit tests. No DB I/O here (except optional /etc/timezone read).
 *
 * Wall clock: instance site TZ from Network panel (`/etc/timezone`) — same as CDR
 * SiteTimezone. Operators enter local office hours; never assume PHP CLI UTC.
 */

/**
 * Apply Network / OS site timezone for schedule evaluation.
 *
 * @param string $tz_file usually /etc/timezone
 * @return string IANA id in effect after call
 */
function pbx3_schedule_use_site_timezone($tz_file = '/etc/timezone')
{
	if (is_readable($tz_file)) {
		$tz = trim((string) @file_get_contents($tz_file));
		if ($tz !== '') {
			try {
				new DateTimeZone($tz);
				date_default_timezone_set($tz);
				return $tz;
			} catch (Exception $e) {
				// fall through
			}
		}
	}
	return date_default_timezone_get();
}

/**
 * Weekday tokens in Mon→Sun order (Asterisk-style abbreviated English).
 *
 * @return string[]
 */
function pbx3_dow_order()
{
	return array('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun');
}

/**
 * Normalize dayofweek field: trim + lowercase. Empty → '*'.
 *
 * @param string|null $spec
 * @return string
 */
function pbx3_dayofweek_normalize($spec)
{
	$s = strtolower(trim((string) $spec));
	return ($s === '') ? '*' : $s;
}

/**
 * Whether dayofweek spec is valid: *, single dow, or forward range start-end (no wrap).
 *
 * @param string|null $spec
 * @return bool
 */
function pbx3_dayofweek_is_valid($spec)
{
	$s = pbx3_dayofweek_normalize($spec);
	if ($s === '*') {
		return true;
	}
	$order = pbx3_dow_order();
	$idx = array_flip($order);
	if (isset($idx[$s])) {
		return true;
	}
	if (!preg_match('/^([a-z]{3})-([a-z]{3})$/', $s, $m)) {
		return false;
	}
	$a = $m[1];
	$b = $m[2];
	if (!isset($idx[$a]) || !isset($idx[$b])) {
		return false;
	}
	// Forward only on Mon→Sun line; reject wrap (tue-mon) and same-day range (use single).
	if ($idx[$a] >= $idx[$b]) {
		return false;
	}
	return true;
}

/**
 * Whether $now's weekday matches dayofweek spec (*, single, or forward range).
 *
 * @param string|null $spec
 * @param int|null $now
 * @return bool
 */
function pbx3_dayofweek_matches($spec, $now = null)
{
	if ($now === null) {
		$now = time();
	}
	$s = pbx3_dayofweek_normalize($spec);
	if ($s === '*') {
		return true;
	}
	if (!pbx3_dayofweek_is_valid($s)) {
		// Invalid stored rows never match (fail closed for that window).
		return false;
	}
	$today = strtolower(date('D', $now));
	$order = pbx3_dow_order();
	$idx = array_flip($order);
	if (!isset($idx[$today])) {
		return false;
	}
	if (strpos($s, '-') === false) {
		return ($s === $today);
	}
	list($a, $b) = explode('-', $s, 2);
	$ti = $idx[$today];
	return ($ti >= $idx[$a] && $ti <= $idx[$b]);
}

/**
 * Whether a dateseg row matches calendar + timespan for $now.
 *
 * @param array $row dateseg fields: month, dayofweek, datemonth, timespan
 * @param int|null $now unix time (default time())
 * @return bool
 */
function pbx3_dateseg_matches(array $row, $now = null)
{
	if ($now === null) {
		$now = time();
	}
	$match = false;

	if (isset($row['month']) && $row['month'] !== '*') {
		if (strtolower((string) $row['month']) !== strtolower(date('M', $now))) {
			return false;
		}
		$match = true;
	}
	if (isset($row['dayofweek']) && $row['dayofweek'] !== '*') {
		if (!pbx3_dayofweek_matches($row['dayofweek'], $now)) {
			return false;
		}
		$match = true;
	}
	if (isset($row['datemonth']) && $row['datemonth'] !== '*') {
		if ((string) $row['datemonth'] !== (string) date('j', $now)) {
			return false;
		}
		$match = true;
	}

	$timespan = isset($row['timespan']) ? (string) $row['timespan'] : '*';

	// All-day style
	if ($timespan === '*-*' || $timespan === '*') {
		// Legacy: "*-*" only counts if some calendar field matched (not four free wildcards)
		if ($timespan === '*-*') {
			return $match === true;
		}
		// timespan only "*" : treat as always matching once calendar passed (same as open window)
		return true;
	}

	if (preg_match('/^(\d\d):(\d\d)-(\d\d):(\d\d)$/', $timespan, $matches)) {
		$tstart = $matches[1] . $matches[2];
		$tend = $matches[3] . $matches[4];
		$hi = date('Hi', $now);
		// Half-open [start, end): start inclusive, end exclusive.
		// Abutting windows (e.g. 20:00-08:30 closed + 08:30-16:30 open) hand off
		// cleanly — no 19:59 / 08:31 fudge times.
		if ($tstart > $tend) {
			// wraps midnight: [start, 24:00) U [00:00, end)
			return ($hi >= $tstart || $hi < $tend);
		}
		return ($hi >= $tstart && $hi < $tend);
	}

	return false;
}

/**
 * Mode string for a matched window (default closed — Q1 convert semantics).
 *
 * @param array $row
 * @return string lowercase mode
 */
function pbx3_dateseg_mode(array $row)
{
	$mode = isset($row['mode']) ? trim((string) $row['mode']) : '';
	if ($mode === '') {
		return 'closed';
	}
	$mode = strtolower($mode);
	if ($mode === 'open' || $mode === 'closed') {
		return $mode;
	}
	return $mode;
}

/**
 * Resolve tenant schedule mode for matching day timers (Q3 priority).
 *
 * @param array $rows list of dateseg rows for one tenant (or all; filtered by cluster if set)
 * @param string|null $cluster only rows for this cluster key if set
 * @param int|null $now
 * @return array{mode:string,winner_pkey:mixed|null,matched_pkeys:array}
 */
function pbx3_resolve_sched_mode(array $rows, $cluster = null, $now = null)
{
	if ($now === null) {
		$now = time();
	}

	$bestPri = null;
	$bestPkey = null;
	$bestMode = 'open'; // Q1 default
	$matched = array();

	foreach ($rows as $row) {
		if ($cluster !== null && isset($row['cluster']) && (string) $row['cluster'] !== (string) $cluster) {
			continue;
		}
		if (!pbx3_dateseg_matches($row, $now)) {
			continue;
		}
		$pkey = isset($row['pkey']) ? $row['pkey'] : (isset($row['id']) ? $row['id'] : null);
		$matched[] = $pkey;
		$pri = isset($row['priority']) ? (int) $row['priority'] : 0;
		$mode = pbx3_dateseg_mode($row);

		// Higher priority wins; ties: first found keeps (stable row order of input)
		if ($bestPri === null || $pri > $bestPri) {
			$bestPri = $pri;
			$bestPkey = $pkey;
			$bestMode = $mode;
		}
	}

	return array(
		'mode' => $bestMode,
		'winner_pkey' => $bestPkey,
		'matched_pkeys' => $matched,
	);
}

/**
 * Dual-write legacy oclo from sched_mode (binary only).
 *
 * @param string $mode
 * @return string OPEN|CLOSED
 */
function pbx3_oclo_from_mode($mode)
{
	$m = strtolower(trim((string) $mode));
	if ($m === 'closed') {
		return 'CLOSED';
	}
	// open and multi-mode (lunch, …): oclo legacy treats non-closed as OPEN
	return 'OPEN';
}

/**
 * Active holiday dest for dual-read (force_dest preferred over legacy route).
 *
 * @param array $row holiday row
 * @return string|null
 */
function pbx3_holiday_force_dest(array $row)
{
	foreach (array('force_dest', 'route') as $k) {
		if (!empty($row[$k]) && trim((string) $row[$k]) !== '') {
			return trim((string) $row[$k]);
		}
	}
	return null;
}

/**
 * Whether holiday row is active at $now (legacy epoch windows).
 *
 * @param array $row
 * @param int|null $now
 * @return bool
 */
function pbx3_holiday_active(array $row, $now = null)
{
	if ($now === null) {
		$now = time();
	}
	if (!isset($row['stime']) || !isset($row['etime'])) {
		return false;
	}
	$st = (int) $row['stime'];
	$et = (int) $row['etime'];
	return ($st <= $now && $et >= $now);
}
