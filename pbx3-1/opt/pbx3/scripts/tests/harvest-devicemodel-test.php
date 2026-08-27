#!/usr/bin/env php
<?php
/**
 * Offline unit checks for UA map + registrar/contact parse (no Asterisk /opt required).
 * Run: php pbx3-1/opt/pbx3/scripts/tests/harvest-devicemodel-test.php
 */

$util = dirname(__DIR__, 2) . '/php/utilities/harvestDevicemodel.php';
if (!is_readable($util)) {
	fwrite(STDERR, "missing $util\n");
	exit(1);
}
require_once $util;

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

$m = pbx3_map_ua_to_vendor_model('Yealink SIP-T46U 108.86.0.90');
expect('yealink T46U', $m && $m[0] === 'Yealink' && $m[1] === 'T46U');

$m = pbx3_map_ua_to_vendor_model('snomD717/10.1.198.19');
expect('snom slash D717', $m && $m[0] === 'Snom' && $m[1] === 'D717');

$m = pbx3_map_ua_to_vendor_model('Yealink SIP-T31P 124.86.0.40');
expect('yealink T31P', $m && $m[0] === 'Yealink' && $m[1] === 'T31P');

$m = pbx3_map_ua_to_vendor_model('Z 5.6.13 v2.10.20.14');
expect('zoiper short Z', $m && $m[0] === 'Zoiper' && $m[1] === '5.6.13');

$m = pbx3_map_ua_to_vendor_model('Zoiper Android 5.6.13');
expect('zoiper named', $m && $m[0] === 'Zoiper' && $m[1] === '5.6.13');

$m = pbx3_map_ua_to_vendor_model('Bria Mobile iOS release 6.23.5 stamp 54641.54641');
expect('bria mobile ios', $m && $m[0] === 'Bria' && $m[1] === 'Mobile iOS 6.23.5');

$m = pbx3_map_ua_to_vendor_model('Bria Mobile Android release 6.20.0 stamp 1.1');
expect('bria mobile android', $m && $m[0] === 'Bria' && $m[1] === 'Mobile Android 6.20.0');

$m = pbx3_map_ua_to_vendor_model('SomeUnknownAgent/1.0');
expect('unknown unmapped', $m === null);

$dump = <<<'TXT'
/registrar/contact/jxpg8b;@abc: {"endpoint":"jxpg8b","user_agent":"Yealink SIP-T46U 108.86.0.90","expiration_time":"9999999999"}
/registrar/contact/pqjfth;@def: {"endpoint":"pqjfth","user_agent":"snomD717/10.1.198.19","expiration_time":"9999999999"}
/registrar/contact/old;@ghi: {"endpoint":"old","user_agent":"Yealink SIP-T46U 1.0","expiration_time":"1"}
TXT;

$parsed = pbx3_parse_registrar_contact_dump($dump);
expect('parse two live', count($parsed) === 2 && isset($parsed['jxpg8b'], $parsed['pqjfth']));
expect('parse skip expired', !isset($parsed['old']));

exit($fail > 0 ? 1 : 0);
