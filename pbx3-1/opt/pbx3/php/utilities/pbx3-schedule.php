<?php
/**
 * Pure schedule evaluation helpers for pbx3timer (day-parts / time-based routing).
 * Injectable $now for unit tests. No DB I/O here.
 */

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
		if (strtolower((string) $row['dayofweek']) !== strtolower(date('D', $now))) {
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
		if ($tstart > $tend) {
			// wraps midnight
			return ($tstart < $hi || $tend > $hi);
		}
		return ($tstart < $hi && $tend > $hi);
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
