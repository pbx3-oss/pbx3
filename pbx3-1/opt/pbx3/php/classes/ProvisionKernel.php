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
			'suffix' => null,
		);
	}

	// Grandstream cfg{mac}.xml (must run before generic 12-hex extract — "cfg" prefix is hex-ish).
	if (preg_match('/^cfg([0-9A-Fa-f]{12})\.xml$/i', $frequest, $gs)) {
		$mac = pbx3_provision_normalize_mac($gs[1]);
		if ($mac === null || $mac === '000000000000') {
			return array(
				'status' => 'not_found',
				'kind' => null,
				'mac' => null,
				'fragment' => null,
				'reason' => 'bad_or_zero_mac',
				'suffix' => null,
			);
		}
		return array(
			'status' => 'ok',
			'kind' => 'mac',
			'mac' => $mac,
			'fragment' => null,
			'reason' => 'grandstream_cfg_xml',
			'suffix' => '.xml',
		);
	}

	// Poly UCS zero-MAC master (classic fallback when per-MAC master missing/wrong).
	if (preg_match('/^000000000000\.cfg$/i', $frequest)) {
		return array(
			'status' => 'ok',
			'kind' => 'poly_master',
			'mac' => null,
			'fragment' => 'poly.Master',
			'reason' => 'poly_master_zero',
			'suffix' => '.cfg',
		);
	}

	if (preg_match('/([0-9A-Fa-f]{12})(.*)$/i', $frequest, $matches)) {
		$mac = pbx3_provision_normalize_mac($matches[1]);
		if ($mac === null || $mac === '000000000000') {
			return array(
				'status' => 'not_found',
				'kind' => null,
				'mac' => null,
				'fragment' => null,
				'reason' => 'bad_or_zero_mac',
				'suffix' => null,
			);
		}
		// Poly reserved / optional names must 404 — never serve the MAC body as an
		// override or directory/license file (would poison {mac}-web.cfg precedence).
		$suffix = isset($matches[2]) ? strtolower((string) $matches[2]) : '';
		if (preg_match('/^-(web|phone|cloud)\.cfg$/', $suffix)
			|| preg_match('/^-(directory|calls)\.xml$/', $suffix)
			|| preg_match('/^-license\.cfg$/', $suffix)) {
			return array(
				'status' => 'not_found',
				'kind' => null,
				'mac' => null,
				'fragment' => null,
				'reason' => 'poly_optional',
				'suffix' => $suffix,
			);
		}
		return array(
			'status' => 'ok',
			'kind' => 'mac',
			'mac' => $mac,
			'fragment' => null,
			'reason' => 'mac_path',
			'suffix' => $suffix,
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
 * Returns false for BLF/fkey names (skip). Prefer pbx3_provision_resolve_include() when DB/cluster available.
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
 * B4 — resolve #INCLUDE: Customer (cluster,pkey) → System file → miss.
 *
 * @return array{kind:string,body:?string,path:?string} kind = customer|system|skip|miss
 */
function pbx3_provision_resolve_include($name, $streamsDir = null, $db = null, $cluster = null) {
	$name = trim((string) $name);
	if ($name === '' || preg_match('/\.\.|[\\\\]/', $name)) {
		return array('kind' => 'miss', 'body' => null, 'path' => null);
	}
	if (preg_match('/\.[LFP]key$/i', $name)) {
		return array('kind' => 'skip', 'body' => null, 'path' => null);
	}

	$clusterKey = $cluster !== null ? trim((string) $cluster) : '';
	if ($clusterKey !== '' && $db instanceof PDO) {
		try {
			$stmt = $db->prepare('SELECT body FROM provision_stream WHERE cluster = ? AND pkey = ? LIMIT 1');
			$stmt->execute(array($clusterKey, $name));
			$row = $stmt->fetch(PDO::FETCH_ASSOC);
			$stmt = null;
			if (is_array($row) && array_key_exists('body', $row)) {
				return array('kind' => 'customer', 'body' => (string) $row['body'], 'path' => null);
			}
		} catch (Exception $e) {
			// table missing in unit fixtures — fall through to System files
		}
	}

	$path = pbx3_provision_stream_path($name, $streamsDir);
	if ($path === false) {
		return array('kind' => 'skip', 'body' => null, 'path' => null);
	}
	if ($path === null) {
		return array('kind' => 'miss', 'body' => null, 'path' => null);
	}
	$raw = @file_get_contents($path);
	if ($raw === false) {
		return array('kind' => 'miss', 'body' => null, 'path' => $path);
	}
	return array('kind' => 'system', 'body' => $raw, 'path' => $path);
}

/**
 * Expand #INCLUDE + accumulate lines. B4: Customer row then System file; miss omits + recorded.
 *
 * @param string $rawConfig
 * @param bool $sndcreds
 * @param string|null $streamsDir
 * @param array $loopCheck
 * @param PDO|null $db
 * @param string|null $cluster
 * @param array|null $includeMisses collected miss names (by ref)
 * @return string
 */
function pbx3_provision_expand($rawConfig, $sndcreds, $streamsDir = null, &$loopCheck = null, $db = null, $cluster = null, &$includeMisses = null) {
	if ($loopCheck === null) {
		$loopCheck = array();
	}
	if ($includeMisses === null) {
		$includeMisses = array();
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
			$resolved = pbx3_provision_resolve_include($devpkey, $streamsDir, $db, $cluster);
			if ($resolved['kind'] === 'skip') {
				continue;
			}
			if ($resolved['kind'] === 'miss') {
				$includeMisses[] = $devpkey;
				continue;
			}
			if (isset($loopCheck[$devpkey])) {
				continue;
			}
			$loopCheck[$devpkey] = true;
			$included = isset($resolved['body']) ? (string) $resolved['body'] : '';
			$ret .= pbx3_provision_expand($included, $sndcreds, $streamsDir, $loopCheck, $db, $cluster, $includeMisses);
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
		'shortuid' => isset($p['shortuid']) ? $p['shortuid'] : (isset($p['pkey']) ? $p['pkey'] : ''),
		// SIP REGISTER / auth username = endpoint shortuid (PJSIP [$id] / username=$id).
		'sipuser' => isset($p['shortuid']) && trim((string) $p['shortuid']) !== ''
			? $p['shortuid']
			: (isset($p['pkey']) ? $p['pkey'] : ''),
		'password' => isset($p['passwd']) ? $p['passwd'] : '',
		'desc' => isset($p['desc']) ? $p['desc'] : (isset($p['cname']) ? $p['cname'] : ''),
		'bindport' => isset($g['bindport']) ? $g['bindport'] : (isset($g['BINDPORT']) ? $g['BINDPORT'] : '5060'),
		'tlsport' => isset($g['tlsport']) ? $g['tlsport'] : (isset($g['TLSPORT']) ? $g['TLSPORT'] : '5061'),
		'localip' => isset($extra['localip']) ? $extra['localip'] : '127.0.0.1',
		'sipdomain' => isset($extra['sipdomain']) ? $extra['sipdomain'] : (isset($extra['registrar']) ? $extra['registrar'] : (isset($extra['localip']) ? $extra['localip'] : '127.0.0.1')),
		'outbound' => isset($extra['outbound']) ? $extra['outbound'] : '',
		'outbound_enable' => isset($extra['outbound_enable']) ? $extra['outbound_enable'] : '0',
		'outbound_hostport' => isset($extra['outbound_hostport']) ? $extra['outbound_hostport'] : '',
		'proxy' => isset($extra['proxy']) ? $extra['proxy'] : (isset($extra['outbound']) && $extra['outbound'] !== '' ? $extra['outbound'] : (isset($extra['sipdomain']) ? $extra['sipdomain'] : '')),
		// Legacy: $registrar = SIP domain (tenant), not SBC.
		'registrar' => isset($extra['registrar']) ? $extra['registrar'] : (isset($extra['sipdomain']) ? $extra['sipdomain'] : (isset($extra['localip']) ? $extra['localip'] : '127.0.0.1')),
		'padminpass' => isset($g['padminpass']) ? $g['padminpass'] : (isset($g['PADMINPASS']) ? $g['PADMINPASS'] : ''),
		'puserpass' => isset($g['puserpass']) ? $g['puserpass'] : (isset($g['PUSERPASS']) ? $g['PUSERPASS'] : ''),
		'ldapbase' => isset($g['ldapbase']) ? $g['ldapbase'] : '',
		'ldaphost' => isset($g['ldaphost']) ? $g['ldaphost'] : '',
		'ldapou' => isset($g['ldapou']) ? $g['ldapou'] : '',
		'ldaptenant' => isset($p['cluster']) ? $p['cluster'] : '',
		'ldaprouser' => '',
		'ldapropwd' => '',
		'provurl' => isset($extra['provurl']) ? $extra['provurl'] : '',
		'mac' => '',
	);
	if (isset($p['macaddr']) && trim((string) $p['macaddr']) !== '') {
		$nm = pbx3_provision_normalize_mac($p['macaddr']);
		if ($nm !== null) {
			$vars['mac'] = $nm;
		}
	}
	foreach ($extra as $k => $v) {
		$vars[$k] = $v;
	}
	// Grandstream P192 wants host:port/path without scheme.
	$vars['provpath'] = preg_replace('#^https?://#i', '', (string) $vars['provurl']);
	return $vars;
}

/**
 * True when the phone row is Poly/UCS (stream or vendor).
 *
 * @param object|array $phone
 */
function pbx3_provision_is_poly_phone($phone) {
	$prov = '';
	$vendor = '';
	if (is_object($phone)) {
		$prov = isset($phone->provision) ? (string) $phone->provision : '';
		$vendor = isset($phone->devicevendor) ? (string) $phone->devicevendor : '';
	} elseif (is_array($phone)) {
		$prov = isset($phone['provision']) ? (string) $phone['provision'] : '';
		$vendor = isset($phone['devicevendor']) ? (string) $phone['devicevendor'] : '';
	}
	if (stripos($prov, 'poly.') !== false || stripos($prov, 'polycom') !== false) {
		return true;
	}
	return (bool) preg_match('/poly/i', $vendor);
}

/**
 * UCS master APPLICATION body (CONFIG_FILES → {mac}-reg.cfg).
 *
 * @param string|null $mac 12-hex MAC; when set, CONFIG_FILES uses a literal
 *        "{mac}-reg.cfg" (more reliable than the phone token on some builds).
 */
function pbx3_provision_poly_master_body($streamsDir = null, $mac = null) {
	$streamsDir = $streamsDir !== null ? $streamsDir : PROVISION_STREAMS;
	$path = pbx3_provision_stream_path('poly.Master', $streamsDir);
	if ($path === null || $path === false) {
		$body = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
			. "<APPLICATION APP_FILE_PATH=\"sip.ld\" CONFIG_FILES=\"[PHONE_MAC_ADDRESS]-reg.cfg\" MISC_FILES=\"\" LOG_FILE_DIRECTORY=\"\" OVERRIDES_DIRECTORY=\"\" CONTACTS_DIRECTORY=\"\" LICENSE_DIRECTORY=\"\" USER_PROFILES_DIRECTORY=\"\" CALL_LISTS_DIRECTORY=\"\">\n"
			. "  <APPLICATION_INFO SERVICE_APP_FILE_PATH=\"\"/>\n"
			. "</APPLICATION>\n";
	} else {
		$body = (string) file_get_contents($path);
	}
	$mac = pbx3_provision_normalize_mac($mac);
	if ($mac !== null) {
		$body = str_replace('[PHONE_MAC_ADDRESS]-reg.cfg', $mac . '-reg.cfg', $body);
	}
	return $body;
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
 * @return array{ok:bool,status:int,body:string,reason:string,phone:?object,include_misses?:array}
 */
function pbx3_provision_render(PDO $db, $parsed, $streamsDir = null, $globals = array(), $extra = array()) {
	if ($parsed['status'] === 'ignore') {
		return array('ok' => true, 'status' => 200, 'body' => "OK\n", 'reason' => $parsed['reason'], 'phone' => null, 'include_misses' => array());
	}
	if ($parsed['status'] !== 'ok') {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => $parsed['reason'], 'phone' => null, 'include_misses' => array());
	}

	$streamsDir = $streamsDir !== null ? $streamsDir : PROVISION_STREAMS;

	if ($parsed['kind'] === 'poly_master') {
		$body = pbx3_provision_poly_master_body($streamsDir, null);
		return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'poly_master', 'phone' => null, 'include_misses' => array());
	}

	if ($parsed['kind'] === 'common') {
		$path = pbx3_provision_stream_path($parsed['fragment'], $streamsDir);
		if ($path === null || $path === false) {
			return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'missing_common', 'phone' => null, 'include_misses' => array());
		}
		$raw = file_get_contents($path);
		$loop = array($parsed['fragment'] => true);
		$misses = array();
		$snd = true; // common file may include admin passwords — treat as Always for common
		$expanded = pbx3_provision_expand($raw, $snd, $streamsDir, $loop, $db, null, $misses);
		$vars = pbx3_provision_vars_from_phone(array(), $globals, $extra);
		$body = pbx3_provision_substitute($expanded, $vars);
		return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'common', 'phone' => null, 'include_misses' => $misses);
	}

	$phone = pbx3_provision_find_phone_by_mac($db, $parsed['mac']);
	if (!$phone) {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'mac_not_found', 'phone' => null, 'include_misses' => array());
	}

	$raw = isset($phone->provision) ? (string) $phone->provision : '';
	if (trim($raw) === '') {
		return array('ok' => false, 'status' => 404, 'body' => "Not Found (404)\n", 'reason' => 'empty_provision', 'phone' => $phone, 'include_misses' => array());
	}

	// Poly: bare {mac}.cfg is the UCS master; settings live in {mac}-reg.cfg.
	$suffix = isset($parsed['suffix']) ? (string) $parsed['suffix'] : '';
	if (pbx3_provision_is_poly_phone($phone) && ($suffix === '.cfg' || $suffix === '')) {
		$body = pbx3_provision_poly_master_body($streamsDir, $parsed['mac']);
		return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'poly_master', 'phone' => $phone, 'include_misses' => array());
	}

	$sndcredsCol = isset($phone->sndcreds) ? $phone->sndcreds : 'Always';
	$snd = pbx3_provision_sndcreds_allows($sndcredsCol);
	$loop = array();
	$misses = array();
	$cluster = isset($phone->cluster) ? (string) $phone->cluster : 'default';
	$expanded = pbx3_provision_expand($raw . "\n", $snd, $streamsDir, $loop, $db, $cluster, $misses);
	$extra = pbx3_provision_merge_phone_hosts($db, $phone, $globals, $extra);
	$globals = pbx3_provision_merge_cluster_device_passwords($db, $phone, $globals);
	$vars = pbx3_provision_vars_from_phone($phone, $globals, $extra);
	$body = pbx3_provision_substitute($expanded, $vars);

	return array('ok' => true, 'status' => 200, 'body' => $body, 'reason' => 'mac', 'phone' => $phone, 'include_misses' => $misses);
}

/**
 * A3 — resolve SIP next-hop / provision URL for solo vs fleet.
 *
 * Fleet: $outbound = SBC (PBX3_SBC_EGRESS_HOST, default sbc.pbx3.com); $sipdomain = tenant FQDN (per phone).
 * Solo: $outbound empty / proxy off; $sipdomain = tenant or instance FQDN / local IP.
 *
 * @param PDO|null $db
 * @param array $globals
 * @param array $overrides optional forced keys
 * @return array{fleet:bool,outbound:string,outbound_enable:string,outbound_hostport:string,localip:string,provurl:string,registrar:string}
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
	$bindport = '5060';
	if (isset($globals['bindport']) && trim((string) $globals['bindport']) !== '') {
		$bindport = trim((string) $globals['bindport']);
	} elseif (isset($globals['BINDPORT']) && trim((string) $globals['BINDPORT']) !== '') {
		$bindport = trim((string) $globals['BINDPORT']);
	}

	if (isset($overrides['outbound'])) {
		$outbound = (string) $overrides['outbound'];
	} elseif ($fleet) {
		$outbound = $sbc;
	} else {
		$outbound = '';
	}
	$outboundEnable = $fleet ? '1' : '0';
	if (isset($overrides['outbound_enable'])) {
		$outboundEnable = (string) $overrides['outbound_enable'];
	}
	$outboundHostport = $outbound !== '' ? ($outbound . ':' . $bindport) : '';
	if (isset($overrides['outbound_hostport'])) {
		$outboundHostport = (string) $overrides['outbound_hostport'];
	}

	// Legacy $registrar in streams meant "SIP host". Prefer $sipdomain; keep registrar
	// as a fill-in for that role only when caller still passes it (tests / overrides).
	$registrar = isset($overrides['registrar']) ? (string) $overrides['registrar'] : '';

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
		'outbound' => $outbound,
		'outbound_enable' => $outboundEnable,
		'outbound_hostport' => $outboundHostport,
		'localip' => $localip,
		'provurl' => $provurl,
		'registrar' => $registrar,
	);
}

/**
 * Device web admin/user passwords live on cluster (padminpass / puserpass), not globals.
 * Globals / PADMINPASS overrides win when already set (unit tests, rare ops override).
 *
 * @param object|array $phone
 * @param array $globals
 * @return array
 */
function pbx3_provision_merge_cluster_device_passwords($db, $phone, $globals = array()) {
	$hasAdmin = (isset($globals['padminpass']) && (string) $globals['padminpass'] !== '')
		|| (isset($globals['PADMINPASS']) && (string) $globals['PADMINPASS'] !== '');
	$hasUser = (isset($globals['puserpass']) && (string) $globals['puserpass'] !== '')
		|| (isset($globals['PUSERPASS']) && (string) $globals['PUSERPASS'] !== '');
	if ($hasAdmin && $hasUser) {
		return $globals;
	}
	$p = is_array($phone) ? $phone : (array) $phone;
	$clusterKey = isset($p['cluster']) ? trim((string) $p['cluster']) : '';
	if ($clusterKey === '' || !($db instanceof PDO)) {
		return $globals;
	}
	try {
		$st = $db->prepare('SELECT padminpass, puserpass FROM cluster WHERE shortuid = ? OR pkey = ? LIMIT 1');
		$st->execute(array($clusterKey, $clusterKey));
		$row = $st->fetch(PDO::FETCH_ASSOC);
		$st = null;
		if (!is_array($row)) {
			return $globals;
		}
		if (!$hasAdmin && isset($row['padminpass']) && (string) $row['padminpass'] !== '') {
			$globals['padminpass'] = (string) $row['padminpass'];
		}
		if (!$hasUser && isset($row['puserpass']) && (string) $row['puserpass'] !== '') {
			$globals['puserpass'] = (string) $row['puserpass'];
		}
	} catch (Exception $e) {
		// table/columns missing in unit fixtures — leave empty
	}
	return $globals;
}

/**
 * Tenant SIP domain for a phone (cluster.fqdn), with solo/instance fallbacks.
 *
 * @param object|array $phone
 * @param array $globals
 * @param array $hosts from pbx3_provision_resolve_hosts (localip)
 */
function pbx3_provision_sipdomain_for_phone($db, $phone, $globals = array(), $hosts = array()) {
	$p = is_array($phone) ? $phone : (array) $phone;
	$clusterKey = isset($p['cluster']) ? trim((string) $p['cluster']) : '';
	$localip = isset($hosts['localip']) ? (string) $hosts['localip'] : '127.0.0.1';

	$apex = '';
	if (isset($globals['domain'])) {
		$apex = trim((string) $globals['domain']);
	} elseif (isset($globals['DOMAIN'])) {
		$apex = trim((string) $globals['DOMAIN']);
	}

	if ($clusterKey !== '' && $db instanceof PDO) {
		try {
			$st = $db->prepare('SELECT fqdn FROM cluster WHERE shortuid = ? OR pkey = ? LIMIT 1');
			$st->execute(array($clusterKey, $clusterKey));
			$row = $st->fetch(PDO::FETCH_ASSOC);
			$st = null;
			if (is_array($row) && isset($row['fqdn']) && trim((string) $row['fqdn']) !== '') {
				return trim((string) $row['fqdn']);
			}
		} catch (Exception $e) {
			// table missing in unit fixtures — fall through
		}
		if ($apex !== '') {
			return $clusterKey . '.' . $apex;
		}
	}

	if (isset($globals['fqdn']) && trim((string) $globals['fqdn']) !== '') {
		return trim((string) $globals['fqdn']);
	}
	if (isset($globals['FQDN']) && trim((string) $globals['FQDN']) !== '') {
		return trim((string) $globals['FQDN']);
	}
	return $localip;
}

/**
 * Merge host/proxy placeholders after MAC → phone is known.
 *
 * @param object|array $phone
 * @param array $globals
 * @param array $extra existing extra (may already include outbound/provurl)
 */
function pbx3_provision_merge_phone_hosts($db, $phone, $globals = array(), $extra = array()) {
	$hosts = pbx3_provision_resolve_hosts($db, $globals, $extra);
	foreach (array('outbound', 'outbound_enable', 'outbound_hostport', 'localip', 'provurl') as $k) {
		if (!isset($extra[$k]) || $extra[$k] === '' || $extra[$k] === null) {
			$extra[$k] = $hosts[$k];
		}
	}
	if (!isset($extra['sipdomain']) || $extra['sipdomain'] === '' || $extra['sipdomain'] === null) {
		$extra['sipdomain'] = pbx3_provision_sipdomain_for_phone($db, $phone, $globals, $extra);
	}
	// Legacy alias: $registrar in vendor streams = SIP domain (not SBC).
	if (!isset($extra['registrar']) || $extra['registrar'] === '' || $extra['registrar'] === null) {
		$extra['registrar'] = $extra['sipdomain'];
	}
	// Panasonic / vendors that always want a proxy field: outbound if set, else sipdomain.
	if (!isset($extra['proxy']) || $extra['proxy'] === '' || $extra['proxy'] === null) {
		$extra['proxy'] = ($extra['outbound'] !== '' && $extra['outbound'] !== null)
			? $extra['outbound']
			: $extra['sipdomain'];
	}
	return $extra;
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
	$misses = isset($result['include_misses']) && is_array($result['include_misses'])
		? array_values(array_unique($result['include_misses']))
		: array();
	$record = array(
		'ts' => gmdate('Y-m-d\\TH:i:s\\Z'),
		'mac' => isset($meta['mac']) ? $meta['mac'] : null,
		'ext' => isset($phone->pkey) ? $phone->pkey : null,
		'cluster' => isset($phone->cluster) ? $phone->cluster : null,
		'sndcreds' => $snd,
		'flipped_once' => $flipped,
		'remote' => isset($meta['remote_addr']) ? $meta['remote_addr'] : null,
		'include_miss' => $misses,
		'body' => pbx3_provision_obfuscate_for_audit($result['body']),
	);
	$audited = pbx3_provision_audit_write($auditPath, $record);

	return array('flipped' => $flipped, 'stamped' => $stamped, 'audited' => $audited);
}
