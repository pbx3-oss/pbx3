<?php
/**
 * Home provision kernel (Phase A1) — PHP lift of sail65 device.php / cleanConfig behaviour.
 *
 * Changes vs prior PBX:
 *  - #INCLUDE resolves vendor-grain **files** under PROVISION_STREAMS (no Device table).
 *  - No BLF / Fkey / Lkey expand ($fkey ignored; *.Fkey includes skipped).
 *  - Secret-line filter does **not** treat $ext as a password token.
 *  - Once→No flip + audit (obfuscated) + last/first_provisioned_at on success path.
 *
 * Pure helpers are callable without Apache; entry is provisioning/device.php.
 */

if (!defined('PROVISION_STREAMS')) {
	define('PROVISION_STREAMS', '/opt/pbx3/provisioning/streams');
}

/**
 * Normalize MAC to 12 lowercase hex (no separators). Returns null if invalid.
 */
function pbx3_provision_normalize_mac($mac) {
	if ($mac === null || $mac === '') {
		return null;
	}
	$hex = strtolower(preg_replace('/[^0-9A-Fa-f]/', '', (string) $mac));
	if (strlen($hex) !== 12 || !ctype_xdigit($hex)) {
		return null;
	}
	return $hex;
}

/**
 * Parse request URI / query into a provision request descriptor.
 *
 * Returns array:
 *   status: 'ok' | 'ignore' | 'not_found'
 *   kind: 'mac' | 'common' | null
 *   mac: string|null (12 hex)
 *   fragment: string|null (common stream name, e.g. yealink.Common)
 *   reason: string
 */
function pbx3_provision_parse_request($method, $requestUri, $query = array()) {
	$method = strtoupper((string) $method);
	if ($method === 'PUT') {
		return array(
			'status' => 'ignore',
			'kind' => null,
			'mac' => null,
			'fragment' => null,
			'reason' => 'put_noop',
		);
	}

	if (isset($query['mac']) && $query['mac'] !== '') {
		$mac = pbx3_provision_normalize_mac($query['mac']);
		if ($mac === null) {
			return array(
				'status' => 'not_found',
				'kind' => null,
				'mac' => null,
				'fragment' => null,
				'reason' => 'bad_mac_query',
			);
		}
		return array(
			'status' => 'ok',
			'kind' => 'mac',
			'mac' => $mac,
			'fragment' => null,
			'reason' => 'mac_query',
		);
	}

	$path = parse_url((string) $requestUri, PHP_URL_PATH);
	if ($path === null || $path === false || $path === '') {
		$path = (string) $requestUri;
	}
	$parts = array_values(array_filter(explode('/', $path), 'strlen'));
	if (count($parts) === 0) {
		return array(
			'status' => 'not_found',
			'kind' => null,
			'mac' => null,
			'fragment' => null,
			'reason' => 'empty_uri',
		);
	}
	// Prefer last path segment as the file request (works for /…/mac.cfg and /mac.cfg).
	$frequest = $parts[count($parts) - 1];

	if (preg_match('/^.*_Security\.enc$/i', $frequest)) {
		return array(
			'status' => 'not_found',
			'kind' => null,
			'mac' => null,
			'fragment' => null,
			'reason' => 'yealink_security',
		);
	}
	if (preg_match('/\.boot$/i', $frequest)) {
		return array(
			'status' => 'not_found',
			'kind' => null,
			'mac' => null,
			'fragment' => null,
			'reason' => 'yealink_boot',
		);
	}
	// Yealink common Y-file → vendor common stream (no MAC).
	if (preg_match('/^y000000(.*)\.cfg$/i', $frequest)) {
		return array(
			'status' => 'ok',
			'kind' => 'common',
			'mac' => null,
			'fragment' => 'yealink.Common',
			'reason' => 'yealink_common',
		);
	}

	if (preg_match('/([0-9A-Fa-f]{12})(.*)$/', $frequest, $matches)) {
		$mac = pbx3_provision_normalize_mac($matches[1]);
		if ($mac === null || $mac === '000000000000') {
			return array(
				'status' => 'not_found',
				'kind' => null,
				'mac' => null,
				'fragment' => null,
				'reason' => 'bad_or_zero_mac',
			);
		}
		return array(
			'status' => 'ok',
			'kind' => 'mac',
			'mac' => $mac,
			'fragment' => null,
			'reason' => 'mac_path',
		);
	}

	return array(
		'status' => 'not_found',
		'kind' => null,
		'mac' => null,
		'fragment' => null,
		'reason' => 'no_mac',
	);
}

/**
 * Secret substrings that must be omitted when sndcreds is No.
 * Intentionally excludes $ext (prior PBX treated ext as secret — wrong for pbx3).
 */
function pbx3_provision_secret_tokens() {
	return array(
		'$password',
		'admin_mode_password',
		'http_user',
		'http_pass',
		'ldap_username',
		'ldap_password',
		'ADMIN_ID',
		'ADMIN_PASS',
		'USER_ID',
		'USER_PASS',
		'LDAP_USERID',
		'LDAP_PASSWORD',
		'security.user_password',
		'ldap.user',
		'ldap.password',
		'$padminpass',
		'$puserpass',
		'$ldaprouser',
		'$ldapropwd',
	);
}

function pbx3_provision_sndcreds_allows($sndcreds) {
	$v = (string) $sndcreds;
	return (bool) preg_match('/^(Always|Once)$/i', $v);
}

/**
 * Resolve #INCLUDE name to a stream file path (null if missing / unsafe).
 */
function pbx3_provision_stream_path($name, $streamsDir = null) {
	$dir = $streamsDir !== null ? $streamsDir : PROVISION_STREAMS;
	$name = trim((string) $name);
	if ($name === '' || preg_match('/\.\.|[\\\\]/', $name)) {
		return null;
	}
	// Skip BLF/line-key templates (no expand in v1).
	if (preg_match('/\.[LFP]key$/i', $name)) {
		return false;
	}
	$path = rtrim($dir, '/') . '/' . $name;
	if (is_readable($path)) {
		return $path;
	}
	if (is_readable($path . '.cfg')) {
		return $path . '.cfg';
	}
	return null;
}

/**
 * Expand #INCLUDE + accumulate lines. No Device table; files only.
 *
 * @param string $rawConfig
 * @param bool $sndcreds
 * @param string|null $streamsDir
 * @param array $loopCheck
 * @return string
 */
function pbx3_provision_expand($rawConfig, $sndcreds, $streamsDir = null, &$loopCheck = null) {
	if ($loopCheck === null) {
		$loopCheck = array();
	}
	$ret = '';
	$lines = explode("\n", (string) $rawConfig);
	$secrets = pbx3_provision_secret_tokens();

	foreach ($lines as $line) {
		$line = preg_replace("/\r/", '', $line);

		// Skip legacy multi-file / HTML cruft from prior PBX exports.
		if (preg_match('/\["(.*)"/', $line)) {
			continue;
		}
		if (preg_match('/^\]\s?$/', $line)) {
			break;
		}
		if (preg_match('/^\<\/?(html|pre)\>$/', $line)) {
			continue;
		}

		if (!$sndcreds) {
			foreach ($secrets as $tok) {
				if (strpos($line, $tok) !== false) {
					continue 2;
				}
			}
		}

		if (preg_match('/^[;#]INCLUDE\s*([\w_\-\.\/\(\)\s]*)\s*$/', $line, $match)) {
			$devpkey = trim($match[1]);
			$path = pbx3_provision_stream_path($devpkey, $streamsDir);
			if ($path === false) {
				// BLF/fkey include — skip silently in v1.
				continue;
			}
			if ($path === null) {
				continue;
			}
			if (isset($loopCheck[$devpkey])) {
				continue;
			}
			$loopCheck[$devpkey] = true;
			$included = file_get_contents($path);
			if ($included === false) {
				continue;
			}
			$ret .= pbx3_provision_expand($included, $sndcreds, $streamsDir, $loopCheck);
			continue;
		}

		$ret .= $line . "\n";
	}

	return $ret;
}

/**
 * Substitute placeholders from phone + globals maps.
 * Unknown placeholders left as-is.
 *
 * @param string $body
 * @param array $vars map of placeholder name (without $) => value
 */
function pbx3_provision_substitute($body, $vars) {
	$out = (string) $body;
	// Longer keys first so $ldapropwd wins over $ldap…
	$keys = array_keys($vars);
	usort($keys, function ($a, $b) {
		return strlen($b) - strlen($a);
	});
	foreach ($keys as $k) {
		$out = str_replace('$' . $k, (string) $vars[$k], $out);
	}
	// Drop stray $fkey marker (no BLF expand).
	$out = str_replace('$fkey', '', $out);
	$out = str_replace("\r", '', $out);
	return $out;
}

/**
 * Build default substitute map from ipphone row + optional globals.
 *
 * @param object|array $phone
 * @param array $globals
 * @param array $extra
 */
function pbx3_provision_vars_from_phone($phone, $globals = array(), $extra = array()) {
	$p = is_array($phone) ? $phone : (array) $phone;
	$g = $globals;
	$vars = array(
		'ext' => isset($p['pkey']) ? $p['pkey'] : '',
		'password' => isset($p['passwd']) ? $p['passwd'] : '',
		'desc' => isset($p['desc']) ? $p['desc'] : (isset($p['cname']) ? $p['cname'] : ''),
		'bindport' => isset($g['bindport']) ? $g['bindport'] : (isset($g['BINDPORT']) ? $g['BINDPORT'] : '5060'),
		'tlsport' => isset($g['tlsport']) ? $g['tlsport'] : (isset($g['TLSPORT']) ? $g['TLSPORT'] : '5061'),
		'localip' => isset($extra['localip']) ? $extra['localip'] : '127.0.0.1',
		'registrar' => isset($extra['registrar']) ? $extra['registrar'] : (isset($extra['localip']) ? $extra['localip'] : '127.0.0.1'),
		'padminpass' => isset($g['padminpass']) ? $g['padminpass'] : (isset($g['PADMINPASS']) ? $g['PADMINPASS'] : ''),
		'puserpass' => isset($g['puserpass']) ? $g['puserpass'] : (isset($g['PUSERPASS']) ? $g['PUSERPASS'] : ''),
		'ldapbase' => isset($g['ldapbase']) ? $g['ldapbase'] : '',
		'ldaphost' => isset($g['ldaphost']) ? $g['ldaphost'] : '',
		'ldapou' => isset($g['ldapou']) ? $g['ldapou'] : '',
		'ldaptenant' => isset($p['cluster']) ? $p['cluster'] : '',
		'ldaprouser' => '',
		'ldapropwd' => '',
		'provurl' => isset($extra['provurl']) ? $extra['provurl'] : '',
	);
	foreach ($extra as $k => $v) {
		$vars[$k] = $v;
	}
	return $vars;
}

/**
 * Look up ipphone by MAC. Fail-closed on 0 or >1 matches.
 *
 * @return object|null
 */
function pbx3_provision_find_phone_by_mac(PDO $db, $mac) {
	$mac = pbx3_provision_normalize_mac($mac);
	if ($mac === null) {
		return null;
	}
	$stmt = $db->prepare('SELECT COUNT(*) FROM ipphone WHERE lower(replace(replace(macaddr, \':\', \'\'), \'-\', \'\')) = ?');
	$stmt->execute(array($mac));
	$count = (int) $stmt->fetchColumn();
	$stmt = null;
	if ($count !== 1) {
		return null;
	}
	$stmt = $db->prepare('SELECT * FROM ipphone WHERE lower(replace(replace(macaddr, \':\', \'\'), \'-\', \'\')) = ? LIMIT 1');
	$stmt->execute(array($mac));
	$row = $stmt->fetch(PDO::FETCH_OBJ);
	$stmt = null;
	return $row ? $row : null;
}

/**
 * Render config for a parsed request.
 *
 * @return array{ok:bool,status:int,body:string,reason:string,phone:?object}
 */
function pbx3_provision_render(PDO $db, $parsed, $streamsDir = null, $globals = array(), $extra = array()) {
	if ($parsed['status'] === 'ignore') {
		return array('ok' => true, 'status' => 200, 'body' => "OK\n", 'reason' => $parsed['reason'], 'phone' => null);
	}
	if ($parsed['status'] !== 'ok') {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => $parsed['reason'], 'phone' => null);
	}

	$streamsDir = $streamsDir !== null ? $streamsDir : PROVISION_STREAMS;

	if ($parsed['kind'] === 'common') {
		$path = pbx3_provision_stream_path($parsed['fragment'], $streamsDir);
		if ($path === null || $path === false) {
			return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'missing_common', 'phone' => null);
		}
		$raw = file_get_contents($path);
		$loop = array($parsed['fragment'] => true);
		$snd = true; // common file may include admin passwords — treat as Always for common
		$expanded = pbx3_provision_expand($raw, $snd, $streamsDir, $loop);
		$vars = pbx3_provision_vars_from_phone(array(), $globals, $extra);
		$body = pbx3_provision_substitute($expanded, $vars);
		return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'common', 'phone' => null);
	}

	$phone = pbx3_provision_find_phone_by_mac($db, $parsed['mac']);
	if (!$phone) {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'mac_not_found', 'phone' => null);
	}

	$raw = isset($phone->provision) ? (string) $phone->provision : '';
	if (trim($raw) === '') {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'empty_provision', 'phone' => $phone);
	}

	$sndcredsCol = isset($phone->sndcreds) ? $phone->sndcreds : 'Always';
	$snd = pbx3_provision_sndcreds_allows($sndcredsCol);
	$loop = array();
	$expanded = pbx3_provision_expand($raw . "\n", $snd, $streamsDir, $loop);
	$vars = pbx3_provision_vars_from_phone($phone, $globals, $extra);
	$body = pbx3_provision_substitute($expanded, $vars);

	return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'mac', 'phone' => $phone);
}

/**
 * A3 — resolve $registrar / $localip / $provurl for solo vs fleet.
 *
 * Fleet: registrar = PBX3_SBC_EGRESS_HOST (default sbc.pbx3.com).
 * Solo: registrar = globals.fqdn when provisionwith=FQDN, else local IPv4 hint.
 *
 * @param PDO|null $db
 * @param array $globals
 * @param array $overrides optional forced keys
 * @return array{fleet:bool,registrar:string,localip:string,provurl:string}
 */
function pbx3_provision_resolve_hosts($db = null, $globals = array(), $overrides = array()) {
	$fleet = pbx3_provision_is_fleet_mode($db);
	$fqdn = '';
	if (isset($globals['fqdn'])) {
		$fqdn = trim((string) $globals['fqdn']);
	} elseif (isset($globals['FQDN'])) {
		$fqdn = trim((string) $globals['FQDN']);
	}

	$sbc = getenv('PBX3_SBC_EGRESS_HOST');
	if ($sbc === false || trim((string) $sbc) === '') {
		$sbc = 'sbc.pbx3.com';
	} else {
		$sbc = trim((string) $sbc);
	}

	$localip = isset($overrides['localip']) ? (string) $overrides['localip'] : '127.0.0.1';
	if ($fleet) {
		$registrar = isset($overrides['registrar']) ? (string) $overrides['registrar'] : $sbc;
	} else {
		if (isset($overrides['registrar'])) {
			$registrar = (string) $overrides['registrar'];
		} elseif ($fqdn !== '') {
			$registrar = $fqdn;
		} else {
			$registrar = $localip;
		}
	}

	$port = defined('PROVISION_PORT') ? PROVISION_PORT : 41363;
	if (isset($overrides['provurl'])) {
		$provurl = (string) $overrides['provurl'];
	} elseif ($fleet) {
		$apex = '';
		if (isset($globals['domain'])) {
			$apex = trim((string) $globals['domain']);
		} elseif (isset($globals['DOMAIN'])) {
			$apex = trim((string) $globals['DOMAIN']);
		}
		if ($apex === '' && $fqdn !== '' && strpos($fqdn, '.') !== false) {
			$apex = preg_replace('/^[^.]+\\./', '', $fqdn);
		}
		if ($apex === '') {
			$apex = 'pbx3.com';
		}
		$provurl = 'https://provision.' . $apex . ':' . $port . '/provisioning';
	} else {
		$host = $fqdn !== '' ? $fqdn : $localip;
		$provurl = 'https://' . $host . ':' . $port . '/provisioning';
	}

	return array(
		'fleet' => $fleet,
		'registrar' => $registrar,
		'localip' => $localip,
		'provurl' => $provurl,
	);
}

/**
 * Same idea as GenClass::isFleetMode — env first, else active trunks.pkey=Egress.
 */
function pbx3_provision_is_fleet_mode($db = null) {
	$env = getenv('PBX3_FLEET_MODE');
	if ($env !== false && $env !== '') {
		$v = strtolower(trim($env));
		if (in_array($v, array('1', 'true', 'yes'), true)) {
			return true;
		}
		if (in_array($v, array('0', 'false', 'no'), true)) {
			return false;
		}
	}
	if (!$db instanceof PDO) {
		return false;
	}
	try {
		$q = $db->query("SELECT active FROM trunks WHERE pkey='Egress' LIMIT 1");
		$row = $q ? $q->fetch(PDO::FETCH_ASSOC) : false;
		return $row && (($row['active'] ?? '') === 'YES');
	} catch (Exception $e) {
		return false;
	}
}

/**
 * A4 — After successful MAC send with sndcreds=Once, flip to No (prepared; == semantics).
 * Returns true if a row was updated.
 */
function pbx3_provision_flip_sndcreds_once(PDO $db, $phone) {
	if (!$phone || !isset($phone->pkey)) {
		return false;
	}
	$mode = isset($phone->sndcreds) ? (string) $phone->sndcreds : '';
	if (strcasecmp($mode, 'Once') !== 0) {
		return false;
	}
	$cluster = isset($phone->cluster) ? (string) $phone->cluster : 'default';
	try {
		$stmt = $db->prepare("UPDATE ipphone SET sndcreds = 'No' WHERE pkey = ? AND cluster = ? AND sndcreds = 'Once'");
		$stmt->execute(array($phone->pkey, $cluster));
		$n = $stmt->rowCount();
		$stmt = null;
		return $n > 0;
	} catch (Exception $e) {
		return false;
	}
}

/**
 * A9 — bump last_provisioned_at (and first if empty) on successful MAC send.
 */
function pbx3_provision_touch_timestamps(PDO $db, $phone, $whenIso = null) {
	if (!$phone || !isset($phone->pkey)) {
		return false;
	}
	if ($whenIso === null) {
		$whenIso = gmdate('Y-m-d\\TH:i:s\\Z');
	}
	$cluster = isset($phone->cluster) ? (string) $phone->cluster : 'default';
	try {
		$stmt = $db->prepare(
			"UPDATE ipphone SET last_provisioned_at = ?,
			 first_provisioned_at = COALESCE(NULLIF(first_provisioned_at, ''), ?)
			 WHERE pkey = ? AND cluster = ?"
		);
		$stmt->execute(array($whenIso, $whenIso, $phone->pkey, $cluster));
		$stmt = null;
		return true;
	} catch (Exception $e) {
		return false;
	}
}

/**
 * A8 — obfuscate secret values in a rendered stream copy for audit storage.
 * Wire response to the phone stays cleartext.
 */
function pbx3_provision_obfuscate_for_audit($body) {
	$lines = explode("\n", (string) $body);
	$out = array();
	$secretKeys = pbx3_provision_secret_tokens();
	foreach ($lines as $line) {
		$masked = $line;
		$hit = false;
		foreach ($secretKeys as $tok) {
			if (strpos($line, $tok) !== false) {
				$hit = true;
				break;
			}
		}
		// Also mask lines that look like assigned passwords after substitute.
		if (!$hit && preg_match('/(password|passwd|user_pass|http_pass|ADMIN_PASS|USER_PASS|ldap\.password|ldap_password)\\s*[:=]/i', $line)) {
			$hit = true;
		}
		if ($hit) {
			// Keep key / left-hand side; mask value.
			if (preg_match('/^(\\s*[^:=]+\\s*[:=]\\s*)(.*)$/', $line, $m)) {
				$masked = $m[1] . '********';
			} else {
				$masked = '********';
			}
		}
		$out[] = $masked;
	}
	return implode("\n", $out);
}

/**
 * Append one JSON audit record (0600 file). Returns true on write.
 */
function pbx3_provision_audit_write($path, $record) {
	$dir = dirname($path);
	if (!is_dir($dir)) {
		@mkdir($dir, 0700, true);
	}
	$line = json_encode($record, JSON_UNESCAPED_SLASHES) . "\n";
	$existed = file_exists($path);
	$ok = (@file_put_contents($path, $line, FILE_APPEND | LOCK_EX) !== false);
	if ($ok && !$existed) {
		@chmod($path, 0600);
	}
	return $ok;
}

/**
 * Side effects after a successful MAC provision send (not common/404/PUT).
 *
 * @param array $result from pbx3_provision_render
 * @param array $meta mac, remote_addr, reason, sndcreds_applied
 */
function pbx3_provision_after_success(PDO $db, $result, $meta = array(), $auditPath = null) {
	if (empty($result['ok']) || (int) $result['status'] !== 200 || $result['reason'] !== 'mac') {
		return array('flipped' => false, 'stamped' => false, 'audited' => false);
	}
	$phone = $result['phone'];
	$flipped = pbx3_provision_flip_sndcreds_once($db, $phone);
	$stamped = pbx3_provision_touch_timestamps($db, $phone);

	if ($auditPath === null) {
		$auditPath = defined('PROVISION_AUDIT_LOG') ? PROVISION_AUDIT_LOG : '/opt/pbx3/var/log/provision-audit.log';
	}
	$snd = isset($phone->sndcreds) ? (string) $phone->sndcreds : '';
	$record = array(
		'ts' => gmdate('Y-m-d\\TH:i:s\\Z'),
		'mac' => isset($meta['mac']) ? $meta['mac'] : null,
		'ext' => isset($phone->pkey) ? $phone->pkey : null,
		'cluster' => isset($phone->cluster) ? $phone->cluster : null,
		'sndcreds' => $snd,
		'flipped_once' => $flipped,
		'remote' => isset($meta['remote_addr']) ? $meta['remote_addr'] : null,
		'body' => pbx3_provision_obfuscate_for_audit($result['body']),
	);
	$audited = pbx3_provision_audit_write($auditPath, $record);

	return array('flipped' => $flipped, 'stamped' => $stamped, 'audited' => $audited);
}
