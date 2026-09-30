#!/usr/bin/env php
<?php
/**
 * A7 skeleton — provision kernel unit checks (no Asterisk /opt required).
 *
 * Run from repo:
 *   php pbx3-1/opt/pbx3/scripts/tests/provision-kernel-test.php
 *
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

// --- INCLUDE + substitute (file fragments) ---
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
	array('localip' => '10.0.0.1', 'registrar' => 'sbc.example')
);
$body = pbx3_provision_substitute("u=\$ext p=\$password h=\$registrar\n\$fkey\n", $vars);
expect('substitute ext/password/registrar', $body === "u=1001 p=s3cret h=sbc.example\n\n");
expect('no \$fkey left', strpos($body, '$fkey') === false);

// --- Fixture SQLite fail-closed ---
$dbFile = $tmp . '/test.db';
$db = new PDO('sqlite:' . $dbFile);
$db->exec('CREATE TABLE ipphone (
  pkey TEXT, macaddr TEXT, passwd TEXT, provision TEXT, provisionwith TEXT,
  desc TEXT, cluster TEXT, sndcreds TEXT
)');
$db->exec("INSERT INTO ipphone VALUES ('1001','aabbccddeeff','pw','#INCLUDE yealink.Extension','FQDN','Desk','t1','Always')");

// Use packaged streams for Yealink stub
$parsed = pbx3_provision_parse_request('GET', '/aabbccddeeff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams, array('PADMINPASS' => 'adm', 'PUSERPASS' => 'usr'), array(
	'localip' => '10.0.0.1',
	'registrar' => 'sbc.example',
));
expect('known mac renders', $r['ok'] && $r['status'] === 200);
expect('body has ext', strpos($r['body'], 'account.1.auth_name = 1001') !== false);
expect('body has password when Always', strpos($r['body'], 'account.1.password = pw') !== false);
expect('body has registrar', strpos($r['body'], 'sbc.example') !== false);

$parsed = pbx3_provision_parse_request('GET', '/ffffffffffff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('unknown mac 404', !$r['ok'] && $r['status'] === 404);

$db->exec("INSERT INTO ipphone VALUES ('1002','aabbccddeeff','pw2','#INCLUDE yealink.Extension','IP','Other','t1','Always')");
$parsed = pbx3_provision_parse_request('GET', '/aabbccddeeff.cfg', array());
$r = pbx3_provision_render($db, $parsed, $streams);
expect('duplicate mac 404', !$r['ok'] && $r['status'] === 404 && $r['reason'] === 'mac_not_found');

// cleanup
@unlink($tmp . '/inner');
@unlink($tmp . '/outer');
@unlink($tmp . '/yealink.Fkey');
@unlink($dbFile);
@rmdir($tmp);

if ($fail) {
	fwrite(STDERR, "$fail failure(s)\n");
	exit(1);
}
echo "All provision-kernel tests passed.\n";
exit(0);
