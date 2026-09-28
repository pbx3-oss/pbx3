#!/usr/bin/env php
<?php
/**
 * Offline GenAst OCLO / VM BLF shortuid keying (#0q).
 *
 * Asserts GenClass + vmnotify use shortuid for AstDB/Custom device-state while
 * keeping Name as the dialable/BLF extension. Emits a two-tenant dialplan
 * fixture with overlapping ext 717.
 *
 * Run: php pbx3-1/opt/pbx3/scripts/tests/genclass-oclo-blf-shortuid-test.php
 */
$root = dirname(__DIR__, 2);
$genClass = "$root/php/classes/GenClass.php";
$vmnotify = "$root/scripts/vmnotify.sh";

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

$src = file_get_contents($genClass);
$vm = file_get_contents($vmnotify);

expect('OCLO uses shortuid OCSTAT', strpos($src, 'ocloSuid . "/OCSTAT")') !== false
	|| (strpos($src, '$ocloSuid') !== false && strpos($src, '/OCSTAT)') !== false));
expect('OCLO dual-writes STATE CLOSED', strpos($src, '/STATE)=CLOSED') !== false);
expect('OCLO dual-writes STATE OPEN', strpos($src, '/STATE)=OPEN') !== false);
expect('OCLO Custom device uses ocloSuid', strpos($src, 'Custom:" . $ocloSuid') !== false);
expect('OCLO dial/hint still uses Name (ocloName)', strpos($src, 'exten => " . $ocloName . ",hint,Custom:') !== false);
expect('no legacy Custom:pkey for OCLO hint', !preg_match('/hint,Custom:"\s*\.\s*\$row\[\'pkey\'\]/', $src));
expect('VM hint Custom:vm-{shortuid}-{ext}', strpos($src, 'Custom:vm-" . $row["shortuid"] . "-" . $phone[\'pkey\']') !== false
	|| strpos($src, 'hint,Custom:vm-" . $row["shortuid"]') !== false);
expect('no bare Custom:vm{ext} hint', !preg_match('/hint,Custom:vm"\s*\.\s*\$phone\[\'pkey\'\]/', $src));

expect('vmnotify uses VM_CONTEXT in Custom id', strpos($vm, 'Custom:vm-${VM_CONTEXT}-${EXTEN}') !== false
	|| strpos($vm, 'Custom:vm-${VM_CONTEXT}-') !== false);
expect('vmnotify not bare Custom:vm$EXTEN', strpos($vm, "Custom:vm'\"\$EXTEN") === false
	&& !preg_match('/Custom:vm"\$EXTEN\'/', $vm)
	&& strpos($vm, 'Custom:vm\'"$EXTEN"') === false);

// --- emit mirror (same shape as GenClass OCLO + VM hint) ---
$tenants = array(
	array('pkey' => 'TenantA', 'shortuid' => 'aaaaaa'),
	array('pkey' => 'TenantB', 'shortuid' => 'bbbbbb'),
);
$ext = '717';
$out = '';
foreach ($tenants as $row) {
	$name = $row['pkey'];
	$suid = $row['shortuid'];
	$out .= "[" . $suid . "]\n";
	$out .= "\texten => " . $name . ",hint,Custom:" . $suid . "\n";
	$out .= "\texten => " . $name . ",1,Set(state=\${DB(" . $suid . "/OCSTAT)})\n";
	$out .= "\texten => " . $name . ",n(" . $name . "close),Set(DB(" . $suid . "/OCSTAT)=CLOSED)\n";
	$out .= "\texten => " . $name . ",n,Set(DB(" . $suid . "/STATE)=CLOSED)\n";
	$out .= "\texten => " . $name . ",n,Set(DEVICE_STATE(Custom:" . $suid . ")=INUSE)\n";
	$out .= "\texten => " . $name . ",n(" . $name . "open),Set(DB(" . $suid . "/OCSTAT)=AUTO)\n";
	$out .= "\texten => " . $name . ",n,Set(DB(" . $suid . "/STATE)=OPEN)\n";
	$out .= "\texten => " . $name . ",n,Set(DEVICE_STATE(Custom:" . $suid . ")=NOT_INUSE)\n";
	$out .= "\texten => *33*,1,GoTo(" . $name . ',' . $name . "open)\n";
	$out .= "\texten => *34*,1,GoTo(" . $name . ',' . $name . "close)\n";
	$out .= "\texten => vm" . $ext . ",hint,Custom:vm-" . $suid . "-" . $ext . "\n";
	$out .= "\n";
}

expect('TenantA OCLO dial Name', strpos($out, "exten => TenantA,hint,Custom:aaaaaa") !== false);
expect('TenantB OCLO dial Name', strpos($out, "exten => TenantB,hint,Custom:bbbbbb") !== false);
expect('TenantA AstDB shortuid OCSTAT', strpos($out, 'DB(aaaaaa/OCSTAT)') !== false);
expect('TenantB AstDB shortuid OCSTAT', strpos($out, 'DB(bbbbbb/OCSTAT)') !== false);
expect('TenantA STATE CLOSED', strpos($out, 'DB(aaaaaa/STATE)=CLOSED') !== false);
expect('TenantB STATE OPEN path', strpos($out, 'DB(bbbbbb/STATE)=OPEN') !== false);
expect('VM BLF TenantA scoped', strpos($out, 'hint,Custom:vm-aaaaaa-717') !== false);
expect('VM BLF TenantB scoped', strpos($out, 'hint,Custom:vm-bbbbbb-717') !== false);
expect('no shared Custom:vm717', strpos($out, 'Custom:vm717') === false);
expect('no Name-family OCSTAT', strpos($out, 'DB(TenantA/OCSTAT)') === false
	&& strpos($out, 'DB(TenantB/OCSTAT)') === false);

if ($fail > 0) {
	fwrite(STDERR, "$fail assertion(s) failed\n");
	exit(1);
}
echo "All OK\n";
exit(0);
