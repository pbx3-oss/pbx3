<?php
/**
 * Home provision kernel (Phase A1) — PHP lift of sail65 device.php / cleanConfig behaviour.
 *
 * Changes vs prior PBX:
 *  - #INCLUDE resolves vendor-grain **files** under PROVISION_STREAMS (no Device table).
 *  - No BLF / Fkey / Lkey expand ($fkey ignored; *.Fkey includes skipped).
 *  - Secret-line filter does **not** treat $ext as a password token.
 *  - Once→No flip / audit / last_provisioned_at are later slices (A4/A8/A9).
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
