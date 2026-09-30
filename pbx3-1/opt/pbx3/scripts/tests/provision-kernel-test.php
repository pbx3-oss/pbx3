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
	'yealink.udp', 'yealink.tcp', 'yealink.tls', 'yealink.ipv4', 'yealink.ipv6', 'Yealink') as $frag) {
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
expect('ETL snom.udp clears outbound', preg_match('/^user_outbound1\$:\s*$/m', $etl) === 1);
expect('ETL snom.ipv4 present', strpos($etl, 'dhcp_v6$: off') !== false);
expect('ETL snom.Fkey still skipped', strpos($etl, 'fkey') === false);

// --- Fixture SQLite ---
$dbFile = $tmp . '/test.db';
$db = new PDO('sqlite:' . $dbFile);
$db->exec('CREATE TABLE ipphone (
  pkey TEXT, macaddr TEXT, passwd TEXT, provision TEXT, provisionwith TEXT,
  desc TEXT, cluster TEXT, sndcreds TEXT,
  last_provisioned_at TEXT, first_provisioned_at TEXT
)');
$db->exec('CREATE TABLE trunks (pkey TEXT, active TEXT)');
$db->exec("INSERT INTO ipphone VALUES ('1001','aabbccddeeff','pw','#INCLUDE yealink.Extension','FQDN','Desk','t1','Once',NULL,NULL)");

$parsed = pbx3_provision_parse_request('GET', '/aabbccddeeff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams, array('PADMINPASS' => 'adm', 'PUSERPASS' => 'usr', 'fqdn' => 'node.example.com'), array(
	'localip' => '10.0.0.1',
	'registrar' => 'sbc.example',
	'provurl' => 'https://provision.example.com:41363/provisioning',
));
expect('known mac renders', $r['ok'] && $r['status'] === 200);
expect('body has ext', strpos($r['body'], 'account.1.auth_name = 1001') !== false);
expect('body has password when Once', strpos($r['body'], 'account.1.password = pw') !== false);
expect('body has registrar', strpos($r['body'], 'sbc.example') !== false);
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
$r2 = pbx3_provision_render($db, $parsed, $streams, array(), array('registrar' => 'sbc.example'));
expect('No omits password line', $r2['ok'] && strpos($r2['body'], 'account.1.password') === false);
expect('No keeps ext', strpos($r2['body'], 'account.1.auth_name = 1001') !== false);
$side2 = pbx3_provision_after_success($db, $r2, array('mac' => 'aabbccddeeff'), $audit);
expect('No does not flip', $side2['flipped'] === false);
$row2 = $db->query("SELECT last_provisioned_at, first_provisioned_at FROM ipphone WHERE pkey='1001'")->fetch(PDO::FETCH_ASSOC);
expect('first unchanged on second send', $row2['first_provisioned_at'] === $row['first_provisioned_at']);
expect('last bumped on second send', $row2['last_provisioned_at'] >= $row['last_provisioned_at']);

// Reset Once and Always
$db->exec("UPDATE ipphone SET sndcreds='Always' WHERE pkey='1001'");
$rA = pbx3_provision_render($db, $parsed, $streams, array(), array('registrar' => 'sbc.example'));
expect('Always includes password', strpos($rA['body'], 'account.1.password = pw') !== false);
$sideA = pbx3_provision_after_success($db, $rA, array('mac' => 'aabbccddeeff'), $audit);
expect('Always does not flip', $sideA['flipped'] === false);

// Snom stream render
$db->exec("UPDATE ipphone SET provision='#INCLUDE snom.Extension', sndcreds='Always', macaddr='001122334455' WHERE pkey='1001'");
$parsedS = pbx3_provision_parse_request('GET', '/001122334455.cfg', array());
$rS = pbx3_provision_render($db, $parsedS, $streams, array('PADMINPASS' => 'adm', 'PUSERPASS' => 'usr'), array('registrar' => 'edge.example', 'provurl' => 'https://p.example/p'));
expect('snom renders', $rS['ok'] && strpos($rS['body'], 'user_name1$: 1001') !== false);
expect('snom registrar', strpos($rS['body'], 'user_host1$: edge.example') !== false);

// Fail-closed
$parsed = pbx3_provision_parse_request('GET', '/ffffffffffff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('unknown mac 404', !$r['ok'] && $r['status'] === 404);
$side404 = pbx3_provision_after_success($db, $r, array('mac' => 'ffffffffffff'), $audit);
expect('404 skips side effects', $side404['flipped'] === false && $side404['stamped'] === false);

$db->exec("INSERT INTO ipphone VALUES ('1002','001122334455','pw2','#INCLUDE yealink.Extension','IP','Other','t1','Once',NULL,NULL)");
$parsed = pbx3_provision_parse_request('GET', '/001122334455.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('duplicate mac 404', !$r['ok'] && $r['status'] === 404 && $r['reason'] === 'mac_not_found');

// A3 host resolution
putenv('PBX3_FLEET_MODE=true');
putenv('PBX3_SBC_EGRESS_HOST=sbc.lab');
$h = pbx3_provision_resolve_hosts($db, array('domain' => 'pbx3.com', 'fqdn' => 'node.pbx3.com'), array('localip' => '10.1.1.1'));
expect('fleet registrar is SBC', $h['fleet'] === true && $h['registrar'] === 'sbc.lab');
expect('fleet provurl', strpos($h['provurl'], 'https://provision.pbx3.com:') === 0);
putenv('PBX3_FLEET_MODE=false');
$h2 = pbx3_provision_resolve_hosts($db, array('fqdn' => 'solo.example.com'), array('localip' => '10.1.1.1'));
expect('solo registrar is fqdn', $h2['fleet'] === false && $h2['registrar'] === 'solo.example.com');
putenv('PBX3_FLEET_MODE');
putenv('PBX3_SBC_EGRESS_HOST');

// Obfuscate unit
$ob = pbx3_provision_obfuscate_for_audit("account.1.password = cleartext\nok=1\n");
expect('obfuscate masks value', strpos($ob, 'cleartext') === false && strpos($ob, '********') !== false && strpos($ob, 'ok=1') !== false);

// cleanup
@unlink($tmp . '/inner');
@unlink($tmp . '/outer');
@unlink($tmp . '/yealink.Fkey');
@unlink($dbFile);
@unlink($audit);
@rmdir($tmp);

if ($fail) {
	fwrite(STDERR, "$fail failure(s)\n");
	exit(1);
}
echo "All provision-kernel tests passed.\n";
exit(0);
