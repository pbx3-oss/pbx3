<?php
/**
 * UA → devicevendor + devicemodel map + AstDB registrar/contact harvest.
 * Invoked by scripts/harvest-devicemodel.sh (cron / manual). Soft-write only.
 *
 * @see workingdocs/EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md
 */

/**
 * Map SIP User-Agent to [devicevendor, devicemodel] or null if unmapped.
 *
 * @return array{0:string,1:string}|null
 */
function pbx3_map_ua_to_vendor_model($ua)
{
	$ua = trim((string) $ua);
	if ($ua === '') {
		return null;
	}

	// Softphones / browsers — harvest skips WebRTC rows; still unmapped here.
	if (preg_match('/Browser Phone|SIPJS|JsSIP/i', $ua)) {
		return null;
	}

	$rules = [
		// order matters: yealink SIP- before broader yealinkDECT
		['yealink', 'Yealink', 'Yealink\sSIP-([\w-]+)\s', 1],
		['yealinkDECT', 'Yealink', 'Yealink\s([\w-]+)\s', 1],
		['cisco', 'Cisco', 'Cisco-CP-(\d{4}-3PCC)', 1],
		['polycom', 'Polycom', 'PolycomVVX-(VVX_\w+)\-UA', 1],
		['snom', 'Snom', '(snom\w+)\-SIP', 1],
		['snom_slash', 'Snom', '^(snomD\d+)', 1],
		['panasonic', 'Panasonic', 'Panasonic_(KX-\w+)\/', 1],
		['aastra', 'Aastra', 'Aastra(\d{4}i)\s', 1],
		['fanvil', 'Fanvil', 'Fanvil\s(\w+)\s', 1],
		['grandstream', 'Grandstream', 'Grandstream\s([\w-]+)', 1],
		['gigaset', 'Gigaset', 'Gigaset\s([\w-]+)', 1],
		// Zoiper lab form: "Z 5.6.13 v2.10.20.14" — product version after Z
		['zoiper_z', 'Zoiper', '^Z\s+([\d.]+)', 1],
		['zoiper', 'Zoiper', 'Zoiper[^0-9]*([\d.]+)', 1],
		// Bria Mobile: "Bria Mobile iOS release 6.23.5 stamp 54641.54641"
		['bria_mobile', 'Bria', 'Bria\s+Mobile\s+(iOS|Android)\s+release\s+([\d.]+)', 2],
		['bria', 'Bria', 'Bria[^0-9]*([\d.]+)', 1],
		// Groundwire (Acrobits): "Groundwire/25.3.101 (build …; iOS 18.7.7; …)"
		['groundwire', 'Groundwire', 'Groundwire/([\d.]+)\s*\([^;]*;\s*(iOS|Android)\s+([\d.]+)', 1],
		// Acrobits cloud path e.g. "Acrobits SIPIS"
		['acrobits', 'Acrobits', '^Acrobits\s+(\S+)', 1],
	];

	foreach ($rules as $rule) {
		[, $vendor, $pattern, $cap] = $rule;
		if (!preg_match('#' . $pattern . '#i', $ua, $m)) {
			continue;
		}
		$model = isset($m[$cap]) ? trim($m[$cap]) : '';
		if ($model === '') {
			continue;
		}
		// snomD717 → D717 for display token
		if (strcasecmp($vendor, 'Snom') === 0 && preg_match('/^snom(.+)$/i', $model, $sm)) {
			$model = $sm[1];
		}
		// Bria Mobile → "Mobile iOS 6.23.5"
		if (strcasecmp($vendor, 'Bria') === 0 && isset($m[1], $m[2])
			&& preg_match('/^(iOS|Android)$/i', $m[1])) {
			$model = 'Mobile ' . $m[1] . ' ' . $m[2];
		}
		// Groundwire → "Mobile iOS 25.3.101" (app version; OS in UA paren is optional context)
		if (strcasecmp($vendor, 'Groundwire') === 0 && isset($m[2])
			&& preg_match('/^(iOS|Android)$/i', $m[2])) {
			$model = 'Mobile ' . $m[2] . ' ' . $model;
		}
		return [$vendor, $model];
	}

	return null;
}

/**
 * Parse `database show registrar/contact` output → endpoint => best contact row.
 *
 * @return array<string, array{user_agent:string, expiration_time:int}>
 */
function pbx3_parse_registrar_contact_dump($text)
{
	$now = time();
	$best = [];
	$lines = preg_split("/\r\n|\n|\r/", (string) $text);
	foreach ($lines as $line) {
		$line = trim($line);
		if ($line === '' || stripos($line, '/registrar/contact/') !== 0) {
			continue;
		}
		$colon = strpos($line, ':');
		if ($colon === false) {
			continue;
		}
		$json = trim(substr($line, $colon + 1));
		$data = json_decode($json, true);
		if (!is_array($data)) {
			continue;
		}
		$endpoint = isset($data['endpoint']) ? trim((string) $data['endpoint']) : '';
		$ua = isset($data['user_agent']) ? trim((string) $data['user_agent']) : '';
		if ($endpoint === '' || $ua === '') {
			continue;
		}
		$exp = isset($data['expiration_time']) ? (int) $data['expiration_time'] : 0;
		if ($exp > 0 && $exp < $now) {
			continue; // expired — leave prior harvest alone
		}
		if (!isset($best[$endpoint]) || $exp >= $best[$endpoint]['expiration_time']) {
			$best[$endpoint] = [
				'user_agent' => $ua,
				'expiration_time' => $exp,
			];
		}
	}
	return $best;
}

/**
 * Soft-update one ipphone row. Returns written|skipped_owned|skipped_type|missing|unmapped.
 */
function pbx3_harvest_soft_update_row(PDO $dbh, $shortuid, $vendor, $model, $nowIso)
{
	$stmt = $dbh->prepare(
		'SELECT id, device, devicevendor, devicemodel, firstseen FROM ipphone WHERE shortuid = ? LIMIT 1'
	);
	$stmt->execute([$shortuid]);
	$row = $stmt->fetch(PDO::FETCH_ASSOC);
	if (!$row) {
		return 'missing';
	}

	$device = trim((string) ($row['device'] ?? ''));
	if (strcasecmp($device, 'WebRTC') === 0 || strcasecmp($device, 'MAILBOX') === 0) {
		return 'skipped_type';
	}

	$curV = trim((string) ($row['devicevendor'] ?? ''));
	$curM = trim((string) ($row['devicemodel'] ?? ''));
	$empty = ($curV === '' && $curM === '');
	$same = (strcasecmp($curV, $vendor) === 0 && strcasecmp($curM, $model) === 0);

	if (!$empty && !$same) {
		return 'skipped_owned';
	}

	$first = trim((string) ($row['firstseen'] ?? ''));
	$firstVal = $first !== '' ? $first : $nowIso;

	$upd = $dbh->prepare(
		'UPDATE ipphone SET devicevendor = ?, devicemodel = ?, firstseen = ?, lastseen = ? WHERE id = ?'
	);
	$upd->execute([$vendor, $model, $firstVal, $nowIso, $row['id']]);
	return 'written';
}

/**
 * Run one harvest pass. Returns counts array.
 */
function pbx3_harvest_devicemodel_run($dumpText = null)
{
	require_once __DIR__ . '/../config.php';
	require_once DBCLASS;

	$counts = [
		'contacts' => 0,
		'endpoints' => 0,
		'written' => 0,
		'skipped_owned' => 0,
		'skipped_type' => 0,
		'unmapped' => 0,
		'missing' => 0,
	];

	if ($dumpText === null) {
		$cmd = 'asterisk -rx ' . escapeshellarg('database show registrar/contact') . ' 2>/dev/null';
		$dumpText = shell_exec($cmd);
		if ($dumpText === null || $dumpText === false) {
			throw new RuntimeException('asterisk database show registrar/contact failed');
		}
	}

	$byEp = pbx3_parse_registrar_contact_dump($dumpText);
	$counts['endpoints'] = count($byEp);
	// rough contact lines for logging
	$counts['contacts'] = substr_count((string) $dumpText, '/registrar/contact/');

	$dbh = DB::getInstance();
	$nowIso = gmdate('Y-m-d\TH:i:s\Z');

	foreach ($byEp as $endpoint => $info) {
		$mapped = pbx3_map_ua_to_vendor_model($info['user_agent']);
		if ($mapped === null) {
			$counts['unmapped']++;
			continue;
		}
		[$vendor, $model] = $mapped;
		$result = pbx3_harvest_soft_update_row($dbh, $endpoint, $vendor, $model, $nowIso);
		if (isset($counts[$result])) {
			$counts[$result]++;
		} elseif ($result === 'written') {
			$counts['written']++;
		}
	}

	return $counts;
}

// CLI entry (not when required for unit tests)
if (php_sapi_name() === 'cli' && isset($_SERVER['SCRIPT_FILENAME'])
	&& realpath($_SERVER['SCRIPT_FILENAME']) === realpath(__FILE__)) {
	require_once __DIR__ . '/../config.php';
	require_once DBCLASS;
	try {
		$c = pbx3_harvest_devicemodel_run();
		fwrite(
			STDOUT,
			sprintf(
				"harvest-devicemodel: contacts=%d endpoints=%d written=%d skipped_owned=%d skipped_type=%d unmapped=%d missing=%d\n",
				$c['contacts'],
				$c['endpoints'],
				$c['written'],
				$c['skipped_owned'],
				$c['skipped_type'],
				$c['unmapped'],
				$c['missing']
			)
		);
		exit(0);
	} catch (Throwable $e) {
		fwrite(STDERR, 'harvest-devicemodel: ' . $e->getMessage() . "\n");
		exit(1);
	}
}
