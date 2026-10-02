#!/usr/bin/env php
<?php
/**
 * Provision kernel unit checks (A1–A4 / A7–A9) — no Asterisk /opt required.
 *
 * Run: php pbx3-1/opt/pbx3/scripts/tests/provision-kernel-test.php
 * Exit 0 on pass, 1 on failure.
 */

$root = dirname(__DIR__, 2); // …/opt/pbx3
$kernel = $root . '/php/classes/ProvisionKernel.php';
$streams = $root . '/provisioning/streams';

if (!is_readable($kernel)) {
	fwrite(STDERR, "missing $kernel\n");
	exit(1);
}
require_once $kernel;

$fail = 0;
function expect($label, $cond) {
	global $fail;
	if ($cond) {
		echo "OK  $label\n";
	} else {
		echo "FAIL $label\n";
		$fail++;
	}
}

// --- URI / MAC parse ---
$p = pbx3_provision_parse_request('GET', '/provisioning/aabbccddeeff.cfg', array());
expect('mac from path', $p['status'] === 'ok' && $p['kind'] === 'mac' && $p['mac'] === 'aabbccddeeff');

$p = pbx3_provision_parse_request('GET', '/', array('mac' => 'AA:BB:CC:DD:EE:FF'));
expect('mac from query', $p['status'] === 'ok' && $p['mac'] === 'aabbccddeeff');

$p = pbx3_provision_parse_request('GET', '/provisioning/y000000000028.cfg', array());
expect('yealink common Y', $p['status'] === 'ok' && $p['kind'] === 'common' && $p['fragment'] === 'yealink.Common');

$p = pbx3_provision_parse_request('GET', '/provisioning/aabbccddeeff_Security.enc', array());
expect('yealink security → 404 path', $p['status'] === 'not_found' && $p['reason'] === 'yealink_security');

$p = pbx3_provision_parse_request('GET', '/provisioning/aabbccddeeff.boot', array());
expect('yealink boot → 404', $p['status'] === 'not_found' && $p['reason'] === 'yealink_boot');

$p = pbx3_provision_parse_request('PUT', '/x', array());
expect('PUT ignore', $p['status'] === 'ignore' && $p['reason'] === 'put_noop');

$p = pbx3_provision_parse_request('GET', '/provisioning/nomac.cfg', array());
expect('no mac → not_found', $p['status'] === 'not_found');

// --- INCLUDE + substitute ---
$tmp = sys_get_temp_dir() . '/pbx3-prov-test-' . getmypid();
@mkdir($tmp);
file_put_contents($tmp . '/inner', "inner_line=\$ext\nsecret=\$password\n");
file_put_contents($tmp . '/outer', "#INCLUDE inner\nouter=\$desc\n");

$loop = array();
$exp = pbx3_provision_expand("#INCLUDE outer\n", true, $tmp, $loop);
expect('include nested', strpos($exp, 'inner_line=$ext') !== false && strpos($exp, 'outer=$desc') !== false);

$loop = array();
$expNo = pbx3_provision_expand("#INCLUDE outer\n", false, $tmp, $loop);
expect('sndcreds No omits $password line', strpos($expNo, '$password') === false);
expect('sndcreds No keeps $ext line', strpos($expNo, 'inner_line=$ext') !== false);

$loop = array('outer' => true, 'inner' => true);
$looped = pbx3_provision_expand("#INCLUDE outer\n#INCLUDE outer\n", true, $tmp, $loop);
expect('loop detection skips second include', substr_count($looped, 'outer=$desc') <= 1);

file_put_contents($tmp . '/yealink.Fkey', "memorykey.1=blf\n");
$loop = array();
$skipFkey = pbx3_provision_expand("#INCLUDE yealink.Fkey\nkeep=1\n", true, $tmp, $loop);
expect('fkey include skipped (no BLF)', strpos($skipFkey, 'memorykey') === false && strpos($skipFkey, 'keep=1') !== false);

$vars = pbx3_provision_vars_from_phone(
	array('pkey' => '1001', 'passwd' => 's3cret', 'desc' => 'Desk', 'cluster' => 't1'),
	array('BINDPORT' => '5060'),
	array('localip' => '10.0.0.1', 'registrar' => 'sbc.example', 'provurl' => 'https://prov.example:41363/p')
);
$body = pbx3_provision_substitute("u=\$ext p=\$password h=\$registrar\n\$fkey\n", $vars);
expect('substitute ext/password/registrar', $body === "u=1001 p=s3cret h=sbc.example\n\n");
expect('no \$fkey left', strpos($body, '$fkey') === false);

// --- A2 packaged streams exist ---
expect('yealink.Common stream', is_readable($streams . '/yealink.Common'));
expect('yealink.Extension stream', is_readable($streams . '/yealink.Extension'));
expect('snom.Common stream', is_readable($streams . '/snom.Common'));
expect('snom.Extension stream', is_readable($streams . '/snom.Extension'));
foreach (array('snom.udp', 'snom.tcp', 'snom.tls', 'snom.ipv4', 'snom.ipv6', 'snom',
	'yealink.udp', 'yealink.tcp', 'yealink.tls', 'yealink.ipv4', 'yealink.ipv6', 'Yealink',
	'Panasonic', 'panasonic.udp', 'panasonic.tcp', 'panasonic.tls', 'panasonic.ipv4',
	'panasonic.ipv6', 'panasonic.Ldap',
	'fanvil.Common', 'fanvil.Extension', 'fanvil.udp') as $frag) {
	expect("stream $frag", is_readable($streams . '/' . $frag));
}
$loop = array();
$etl = pbx3_provision_expand(
	"#INCLUDE snom\n#INCLUDE snom.Fkey\n#INCLUDE snom.udp\n#INCLUDE snom.ipv4\n",
	true,
	$streams,
	$loop
);
expect('ETL snom+udp expands common', strpos($etl, 'setting_server$:') !== false);
expect('ETL snom.udp keeps outbound_hostport', preg_match('/^user_outbound1\$:\s*\$outbound_hostport\s*$/m', $etl) === 1);
expect('ETL snom.ipv4 present', strpos($etl, 'dhcp_v6$: off') !== false);
expect('ETL snom.Fkey still skipped', strpos($etl, 'fkey') === false);
$loop = array();
$pana = pbx3_provision_expand(
	"#INCLUDE Panasonic\n#INCLUDE panasonic.Fkey\n#INCLUDE panasonic.tcp\n#INCLUDE panasonic.ipv4\n",
	true,
	$streams,
	$loop
);
expect('ETL Panasonic expands', strpos($pana, 'Panasonic SIP Phone') !== false);
expect('ETL panasonic.tcp transport', strpos($pana, 'SIP_TRANSPORT_1="1"') !== false);
expect('ETL panasonic.ipv4', strpos($pana, 'IP_ADDR_MODE="0"') !== false);
$loop = array();
$fanvil = pbx3_provision_expand(
	"#INCLUDE fanvil.Extension\n#INCLUDE fanvil.udp\n",
	true,
	$streams,
	$loop
);
expect('ETL fanvil module XML', strpos($fanvil, '<VOIP_CONFIG_FILE>') !== false && strpos($fanvil, '<SIP_CONFIG_MODULE>') !== false);
expect('ETL fanvil INCLUDE stripped', strpos($fanvil, '#INCLUDE') === false);
expect('ETL fanvil Register_Addr placeholder', strpos($fanvil, '<Register_Addr>$sipdomain</Register_Addr>') !== false);
expect('ETL fanvil Proxy_Addr outbound', strpos($fanvil, '<Proxy_Addr>$outbound</Proxy_Addr>') !== false);

// --- Fixture SQLite ---
$dbFile = $tmp . '/test.db';
$db = new PDO('sqlite:' . $dbFile);
$db->exec('CREATE TABLE ipphone (
  pkey TEXT, shortuid TEXT, macaddr TEXT, passwd TEXT, provision TEXT, provisionwith TEXT,
  desc TEXT, cluster TEXT, sndcreds TEXT,
  last_provisioned_at TEXT, first_provisioned_at TEXT
)');
$db->exec('CREATE TABLE trunks (pkey TEXT, active TEXT)');
$db->exec("INSERT INTO ipphone VALUES ('1001','su1001','aabbccddeeff','pw','#INCLUDE yealink.Extension','FQDN','Desk','t1','Once',NULL,NULL)");

$parsed = pbx3_provision_parse_request('GET', '/aabbccddeeff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams, array('PADMINPASS' => 'adm', 'PUSERPASS' => 'usr', 'fqdn' => 'node.example.com', 'domain' => 'example.com'), array(
	'localip' => '10.0.0.1',
	'sipdomain' => 't1.example.com',
	'outbound' => 'sbc.example',
	'outbound_enable' => '1',
	'outbound_hostport' => 'sbc.example:5060',
	'provurl' => 'https://provision.example.com:41363/provisioning',
));
expect('known mac renders', $r['ok'] && $r['status'] === 200);
expect('body has sipuser', strpos($r['body'], 'account.1.auth_name = su1001') !== false);
expect('body has label ext', strpos($r['body'], 'account.1.label = 1001') !== false);
expect('body has password when Once', strpos($r['body'], 'account.1.password = pw') !== false);
expect('body has sipdomain', strpos($r['body'], 'account.1.sip_server_host = t1.example.com') !== false);
expect('body has outbound SBC', strpos($r['body'], 'account.1.outbound_host = sbc.example') !== false);
expect('body has outbound enable', strpos($r['body'], 'account.1.outbound_proxy_enable = 1') !== false);
expect('yealink common nested', strpos($r['body'], '#!version:1.0.0.1') !== false);

// A4/A8/A9 success path
$audit = $tmp . '/audit.log';
$side = pbx3_provision_after_success($db, $r, array('mac' => 'aabbccddeeff', 'remote_addr' => '9.9.9.9'), $audit);
expect('Once flipped to No', $side['flipped'] === true);
$row = $db->query("SELECT sndcreds, last_provisioned_at, first_provisioned_at FROM ipphone WHERE pkey='1001'")->fetch(PDO::FETCH_ASSOC);
expect('sndcreds now No', $row && $row['sndcreds'] === 'No');
expect('last_provisioned_at set', $row && $row['last_provisioned_at'] !== null && $row['last_provisioned_at'] !== '');
expect('first_provisioned_at set', $row && $row['first_provisioned_at'] !== null && $row['first_provisioned_at'] !== '');
expect('audit file written', is_readable($audit));
$alog = file_get_contents($audit);
expect('audit has mac', strpos($alog, 'aabbccddeeff') !== false);
expect('audit obfuscates password', strpos($alog, 'account.1.password = pw') === false && strpos($alog, '********') !== false);

// Second render with No — password omitted; no flip; stamp still updates
$parsed = pbx3_provision_parse_request('GET', '/aabbccddeeff.cfg', array());
$r2 = pbx3_provision_render($db, $parsed, $streams, array('domain' => 'example.com'), array(
	'sipdomain' => 't1.example.com',
	'outbound' => 'sbc.example',
	'outbound_enable' => '1',
	'outbound_hostport' => 'sbc.example:5060',
));
expect('No omits password line', $r2['ok'] && strpos($r2['body'], 'account.1.password') === false);
expect('No keeps sipuser', strpos($r2['body'], 'account.1.auth_name = su1001') !== false);
$side2 = pbx3_provision_after_success($db, $r2, array('mac' => 'aabbccddeeff'), $audit);
expect('No does not flip', $side2['flipped'] === false);
$row2 = $db->query("SELECT last_provisioned_at, first_provisioned_at FROM ipphone WHERE pkey='1001'")->fetch(PDO::FETCH_ASSOC);
expect('first unchanged on second send', $row2['first_provisioned_at'] === $row['first_provisioned_at']);
expect('last bumped on second send', $row2['last_provisioned_at'] >= $row['last_provisioned_at']);

// Reset Once and Always
$db->exec("UPDATE ipphone SET sndcreds='Always' WHERE pkey='1001'");
$rA = pbx3_provision_render($db, $parsed, $streams, array('domain' => 'example.com'), array(
	'sipdomain' => 't1.example.com',
	'outbound' => 'sbc.example',
	'outbound_enable' => '1',
));
expect('Always includes password', strpos($rA['body'], 'account.1.password = pw') !== false);
$sideA = pbx3_provision_after_success($db, $rA, array('mac' => 'aabbccddeeff'), $audit);
expect('Always does not flip', $sideA['flipped'] === false);

// Snom stream render
$db->exec("UPDATE ipphone SET provision='#INCLUDE snom.Extension', sndcreds='Always', macaddr='001122334455' WHERE pkey='1001'");
$parsedS = pbx3_provision_parse_request('GET', '/001122334455.cfg', array());
$rS = pbx3_provision_render($db, $parsedS, $streams, array('PADMINPASS' => 'adm', 'PUSERPASS' => 'usr', 'domain' => 'example.com'), array(
	'sipdomain' => 't1.example.com',
	'outbound' => 'edge.example',
	'outbound_enable' => '1',
	'outbound_hostport' => 'edge.example:5060',
	'provurl' => 'https://p.example/p',
));
expect('snom renders', $rS['ok'] && strpos($rS['body'], 'user_name1$: su1001') !== false);
expect('snom sipdomain', strpos($rS['body'], 'user_host1$: t1.example.com') !== false);
expect('snom outbound', strpos($rS['body'], 'user_outbound1$: edge.example:5060') !== false);

// Fail-closed
$parsed = pbx3_provision_parse_request('GET', '/ffffffffffff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('unknown mac 404', !$r['ok'] && $r['status'] === 404);
$side404 = pbx3_provision_after_success($db, $r, array('mac' => 'ffffffffffff'), $audit);
expect('404 skips side effects', $side404['flipped'] === false && $side404['stamped'] === false);

$db->exec("INSERT INTO ipphone VALUES ('1002','su1002','001122334455','pw2','#INCLUDE yealink.Extension','IP','Other','t1','Once',NULL,NULL)");
$parsed = pbx3_provision_parse_request('GET', '/001122334455.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('duplicate mac 404', !$r['ok'] && $r['status'] === 404 && $r['reason'] === 'mac_not_found');

// A3 host resolution
putenv('PBX3_FLEET_MODE=true');
putenv('PBX3_SBC_EGRESS_HOST=sbc.lab');
$h = pbx3_provision_resolve_hosts($db, array('domain' => 'pbx3.com', 'fqdn' => 'node.pbx3.com'), array('localip' => '10.1.1.1'));
expect('fleet outbound is SBC', $h['fleet'] === true && $h['outbound'] === 'sbc.lab' && $h['outbound_enable'] === '1');
expect('fleet provurl', strpos($h['provurl'], 'https://provision.pbx3.com:') === 0);
$db->exec('CREATE TABLE cluster (pkey TEXT, shortuid TEXT, fqdn TEXT)');
$db->exec("INSERT INTO cluster VALUES ('t1','t1','t1.example.com')");
$sip = pbx3_provision_sipdomain_for_phone($db, array('cluster' => 't1'), array('domain' => 'example.com'), array('localip' => '10.1.1.1'));
expect('sipdomain from cluster.fqdn', $sip === 't1.example.com');
putenv('PBX3_FLEET_MODE=false');
$h2 = pbx3_provision_resolve_hosts($db, array('fqdn' => 'solo.example.com'), array('localip' => '10.1.1.1'));
expect('solo outbound empty', $h2['fleet'] === false && $h2['outbound'] === '' && $h2['outbound_enable'] === '0');
putenv('PBX3_FLEET_MODE');
putenv('PBX3_SBC_EGRESS_HOST');

// Obfuscate unit
$ob = pbx3_provision_obfuscate_for_audit("account.1.password = cleartext\nok=1\n");
expect('obfuscate masks value', strpos($ob, 'cleartext') === false && strpos($ob, '********') !== false && strpos($ob, 'ok=1') !== false);

// --- B4 Customer site fragments ---
$db->exec('CREATE TABLE provision_stream (
  id TEXT, shortuid TEXT, pkey TEXT, cluster TEXT, body TEXT, notes TEXT, updated_at TEXT
)');
$db->exec("INSERT INTO provision_stream VALUES ('id1','su1','site.ReceptionBLF','t1','linekey.1=blf\nlinekey.1.value=1002\n',NULL,NULL)");
file_put_contents($tmp . '/snom.Extension', "base=system\n");
$loop = array();
$misses = array();
$expCust = pbx3_provision_expand(
	"#INCLUDE snom.Extension\n#INCLUDE site.ReceptionBLF\n",
	true,
	$tmp,
	$loop,
	$db,
	't1',
	$misses
);
expect('B4 customer after system', strpos($expCust, 'base=system') !== false && strpos($expCust, 'linekey.1=blf') !== false);
expect('B4 no miss when customer present', count($misses) === 0);

$loop = array();
$misses = array();
$expMiss = pbx3_provision_expand("#INCLUDE site.MissingThing\nkeep=1\n", true, $tmp, $loop, $db, 't1', $misses);
expect('B4 miss omits body', strpos($expMiss, 'keep=1') !== false);
expect('B4 miss recorded', in_array('site.MissingThing', $misses, true));

$loop = array();
$misses = array();
$expCustWins = pbx3_provision_expand(
	"#INCLUDE site.ReceptionBLF\n",
	true,
	$tmp,
	$loop,
	$db,
	't1',
	$misses
);
expect('B4 customer preferred over missing system', strpos($expCustWins, 'linekey.1=blf') !== false);

$rCust = pbx3_provision_resolve_include('site.ReceptionBLF', $tmp, $db, 't1');
expect('B4 resolve kind customer', $rCust['kind'] === 'customer');
$rSys = pbx3_provision_resolve_include('snom.Extension', $tmp, $db, 't1');
expect('B4 resolve kind system', $rSys['kind'] === 'system');

// cleanup
@unlink($tmp . '/inner');
@unlink($tmp . '/outer');
@unlink($tmp . '/yealink.Fkey');
@unlink($tmp . '/snom.Extension');
@unlink($dbFile);
@unlink($audit);
@rmdir($tmp);

if ($fail) {
	fwrite(STDERR, "$fail failure(s)\n");
	exit(1);
}
echo "All provision-kernel tests passed.\n";
exit(0);
