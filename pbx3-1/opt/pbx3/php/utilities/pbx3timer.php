<?php
// +-----------------------------------------------------------------------+
// | Time-based routing timer — day segments + holidays (cron ~1/min)        |
// +-----------------------------------------------------------------------+
// Precompute cluster.sched_mode (+ dual-write oclo), dateseg.state, holiday
// routeoverride / holiday_force_dest. Call path: CAGI CheckState (O(1)).
//
// Requires: pbx3-schedule.php pure helpers (unit-tested).

require_once __DIR__ . "/../config.php";
require_once DBCLASS;
require_once HELPER;
require_once __DIR__ . "/pbx3-schedule.php";

	$helper = new helper;
	$dbh = DB::getInstance();
	$cluster_mode = array();   // pkey => mode string
	$holarray = array();
	$dateseg_state = array();
	$tuple = array();
	$dbupdated = false;
	$debug = false;
	$now = time();

	$helper->logit(" SYSTIMER Started", 10 );

	// --- Holidays (legacy epochs; dual-write routeoverride + holiday_force_dest) ---

	$rows = $helper->getTable("cluster");
	foreach ($rows as $row) {
		$holarray[$row['pkey']] = array(
			'cluster' => $row['pkey'],
			'route' => null,
		);
	}

	$holidays = $helper->getTable("holiday");
	foreach ($holidays as $row) {
		if (!pbx3_holiday_active($row, $now)) {
			continue;
		}
		$dest = pbx3_holiday_force_dest($row);
		$ck = isset($row['cluster']) ? $row['cluster'] : null;
		if ($ck === null || $ck === '') {
			continue;
		}
		// Prefer index by cluster key as stored (pkey or shortuid)
		$holarray[$ck] = array(
			'cluster' => $ck,
			'route' => $dest,
		);
	}

	if ($debug) {
		print_r($holarray);
	}

	foreach ($holarray as $k) {
		$ck = $k['cluster'];
		// Match either pkey or shortuid
		$res = $dbh->query(
			"SELECT pkey, routeoverride, holiday_force_dest FROM cluster WHERE pkey=" .
			$dbh->quote($ck) . " OR shortuid=" . $dbh->quote($ck)
		)->fetch(PDO::FETCH_ASSOC);
		if (!$res) {
			continue;
		}
		$want = $k['route']; // may be null → clear
		if ($want === null) {
			$want = '';
		}
		$cur_ro = isset($res['routeoverride']) ? $res['routeoverride'] : '';
		$cur_fd = isset($res['holiday_force_dest']) ? $res['holiday_force_dest'] : '';
		if ((string) $cur_ro === (string) $want && (string) $cur_fd === (string) $want) {
			continue;
		}
		$tuple = array(
			'pkey' => $res['pkey'],
			'routeoverride' => $want,
			'holiday_force_dest' => $want,
		);
		$helper->setTuple('cluster', $tuple);
		$helper->logit(
			"Updated Cluster " . $res['pkey'] . " holiday dest " . var_export($want, true),
			0
		);
		$dbupdated = true;
	}

	// --- Day timers → sched_mode (priority win) + dual-write oclo ---

	$rows = $helper->getTable("cluster");
	$cluster_by_pkey = array();
	foreach ($rows as $row) {
		$cluster_by_pkey[$row['pkey']] = $row;
		$cluster_mode[$row['pkey']] = 'open';
	}

	$all_dateseg = $helper->getTable("dateseg");
	foreach ($all_dateseg as $row) {
		$dateseg_state[isset($row['pkey']) ? $row['pkey'] : $row['id']] = 'IDLE';
	}

	// Resolve per cluster: collect rows by cluster key matching pkey OR shortuid
	foreach ($cluster_by_pkey as $pkey => $crow) {
		$aliases = array($pkey);
		if (!empty($crow['shortuid'])) {
			$aliases[] = $crow['shortuid'];
		}
		$tenant_rows = array();
		foreach ($all_dateseg as $row) {
			$rc = isset($row['cluster']) ? (string) $row['cluster'] : '';
			if ($rc !== '' && in_array($rc, $aliases, true)) {
				$tenant_rows[] = $row;
			}
		}
		$res = pbx3_resolve_sched_mode($tenant_rows, null, $now);
		$cluster_mode[$pkey] = $res['mode'];
		if ($res['winner_pkey'] !== null) {
			$dateseg_state[$res['winner_pkey']] = '*INUSE*';
		}
		// Mark all matched still visible? Spec: winner *INUSE* only — already set
	}

	foreach ($cluster_mode as $pkey => $mode) {
		$oclo = pbx3_oclo_from_mode($mode);
		$row = $dbh->query(
			"SELECT oclo, sched_mode FROM cluster WHERE pkey=" . $dbh->quote($pkey)
		)->fetch(PDO::FETCH_ASSOC);
		if (!$row) {
			continue;
		}
		$cur_oclo = isset($row['oclo']) ? $row['oclo'] : '';
		$cur_sm = isset($row['sched_mode']) ? $row['sched_mode'] : '';
		if ($cur_oclo === $oclo && strtolower((string) $cur_sm) === strtolower((string) $mode)) {
			continue;
		}
		$tuple = array(
			'pkey' => $pkey,
			'oclo' => $oclo,
			'sched_mode' => $mode,
		);
		$helper->setTuple('cluster', $tuple);
		$dbupdated = true;
		$helper->logit("Cluster $pkey sched_mode=$mode oclo=$oclo", 5);
	}

	if ($debug) {
		print_r($dateseg_state);
		print_r($cluster_mode);
	}

	foreach ($dateseg_state as $k => $v) {
		$state = $dbh->query(
			"SELECT state FROM dateseg WHERE pkey=" . $dbh->quote($k)
		)->fetch(PDO::FETCH_ASSOC);
		if (!$state) {
			// try id
			$state = $dbh->query(
				"SELECT state FROM dateseg WHERE id=" . $dbh->quote($k)
			)->fetch(PDO::FETCH_ASSOC);
			if (!$state) {
				continue;
			}
			if ($state['state'] == $v) {
				continue;
			}
			// update by id if no pkey path — setTuple may need pkey
			continue;
		}
		if ($state['state'] == $v) {
			continue;
		}
		$tuple = array(
			'pkey' => $k,
			'state' => $v,
		);
		$helper->setTuple('dateseg', $tuple);
		$dbupdated = true;
	}

	if ($dbupdated == true) {
		$helper->logit(" CODENAME TIMER MODIFY", 10 );
		$cmd = '/usr/bin/sqlite3 '.SYSDB.' "UPDATE globals SET mycommit=\'NO\';"';
		`$cmd`;
		$rc = `/bin/cp SYSDB COPY_DB`;
		$rc = `/bin/mv COPY_DB READONLYDB`;
	}
	$helper->logit(" CODENAME TIMER Ended", 10 );
