#!/usr/bin/env php
<?php
/**
 * Offline GenAst CoS profiles Slice B checks (no Asterisk /opt required).
 *
 * 1) Source shape: GenClass + tmpls use profile contexts; no per-phone opencos.
 * 2) Fixture emit: convert junctions → profiles, then build dialplan with the same
 *    SQL GenClass uses and assert O(profiles) contexts, floor includes, bypass.
 *
 * Run: php pbx3-1/opt/pbx3/scripts/tests/genclass-cos-profiles-test.php
 */
$root = dirname(__DIR__, 2);
$genClass = "$root/php/classes/GenClass.php";
$phoneTmpl = "$root/etc/asterisk/templates/pjsip_phone.tmpl";
$webrtcTmpl = "$root/etc/asterisk/templates/pjsip_webrtc.tmpl";
$apply = "$root/scripts/apply-sqlite-add-cos-profiles.sh";
$convert = "$root/scripts/convert-cos-profiles.sh";

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
expect('no per-phone opencos emit', strpos($src, 'opencos]') === false);
expect('no per-phone closedcos emit', strpos($src, 'closedcos]') === false);
expect('no CALLERID opencos dispatch', strpos($src, 'CALLERID(num)}opencos') === false);
expect('profile entry COS_ emit', strpos($src, 'COS_') !== false && strpos($src, '_open]') !== false);
expect('resolveCosProfilePkey present', strpos($src, 'function resolveCosProfilePkey') !== false);
expect('cos_context token in xlate', strpos($src, '$cos_context') !== false);

$pt = file_get_contents($phoneTmpl);
$wt = file_get_contents($webrtcTmpl);
expect('phone tmpl uses $cos_context', strpos($pt, 'context=$cos_context') !== false);
expect('webrtc tmpl uses $cos_context', strpos($wt, 'context=$cos_context') !== false);
expect('phone tmpl not legacy COS_$clst alone', !preg_match('/context=COS_\$clst\s*$/m', $pt));

// --- fixture DB + convert + emit ---
$workdir = sys_get_temp_dir() . '/cos-genast-' . bin2hex(random_bytes(4));
mkdir($workdir, 0700, true);
$db = "$workdir/test.db";

$pdo = new PDO('sqlite:' . $db);
$pdo->exec(<<<'SQL'
CREATE TABLE cos (
  pkey TEXT NOT NULL,
  cluster TEXT DEFAULT 'default',
  dialplan TEXT,
  defaultopen TEXT DEFAULT 'NO',
  defaultclosed TEXT DEFAULT 'NO',
  orideopen TEXT DEFAULT 'NO',
  orideclosed TEXT DEFAULT 'NO'
);
CREATE TABLE ipphone (
  id TEXT PRIMARY KEY,
  pkey TEXT NOT NULL,
  cluster TEXT DEFAULT 'default',
  active TEXT DEFAULT 'YES'
);
CREATE TABLE ipphonecosopen (
  cluster TEXT, ipphone_pkey TEXT, cos_pkey TEXT,
  PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);
CREATE TABLE ipphonecosclosed (
  cluster TEXT, ipphone_pkey TEXT, cos_pkey TEXT,
  PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);
INSERT INTO cos (pkey, cluster, dialplan, defaultopen, defaultclosed, orideopen, orideclosed) VALUES
  ('Intl', 'tenanta', '_441.', 'YES', 'YES', 'NO', 'NO'),
  ('HR_Premium', 'tenanta', '_09.', 'YES', 'YES', 'YES', 'YES'),
  ('LocalOnly', 'tenanta', '_9.', 'NO', 'NO', 'NO', 'NO');
INSERT INTO ipphone (id, pkey, cluster) VALUES
  ('1', '1001', 'tenanta'),
  ('2', '1002', 'tenanta'),
  ('3', '1003', 'tenanta'),
  ('4', '1004', 'tenanta');
-- 1001/1002 Staff: open Intl; closed Intl
INSERT INTO ipphonecosopen VALUES ('tenanta','1001','Intl'),('tenanta','1002','Intl');
INSERT INTO ipphonecosclosed VALUES ('tenanta','1001','Intl'),('tenanta','1002','Intl');
-- 1003 Restricted: open LocalOnly; closed LocalOnly+Intl
INSERT INTO ipphonecosopen VALUES ('tenanta','1003','LocalOnly');
INSERT INTO ipphonecosclosed VALUES ('tenanta','1003','LocalOnly'),('tenanta','1003','Intl');
-- 1004 empty → Unrestricted
SQL);

passthru('bash ' . escapeshellarg($apply) . ' ' . escapeshellarg($db), $rc1);
passthru('bash ' . escapeshellarg($convert) . ' ' . escapeshellarg($db), $rc2);
expect('apply+convert exit 0', $rc1 === 0 && $rc2 === 0);

$nProf = (int) $pdo->query("SELECT count(*) FROM cos_profile WHERE cluster='tenanta'")->fetchColumn();
$nPhone = (int) $pdo->query("SELECT count(*) FROM ipphone WHERE cluster='tenanta'")->fetchColumn();
expect("profiles O(fingerprints) not O(phones) ($nProf < $nPhone)", $nProf >= 2 && $nProf < $nPhone);

// Emit dialplan (mirrors GenClass::genExtensionsCoS + genExtensionsCosTests)
$out = '';
$emergency = '999 112';
$profiles = $pdo->query("SELECT * FROM cos_profile WHERE upper(trim(coalesce(active,'YES'))) = 'YES' ORDER BY cluster, pkey")->fetchAll(PDO::FETCH_ASSOC);
foreach ($profiles as $prof) {
	$clst = $prof['cluster'];
	$ppkey = $prof['pkey'];
	$ctx = "COS_{$clst}_{$ppkey}";
	$out .= "[$ctx]\n";
	$out .= "\texten => _*X.,1,GoTo($clst,\${EXTEN},1)\n";
	foreach (explode(' ', $emergency) as $plan) {
		$out .= "\texten => $plan,1,GoTo($clst,\${EXTEN},1)\n";
	}
	for ($p = 901; $p <= 903; $p++) {
		$out .= "\texten => $p,1,GoTo($clst,\${EXTEN},1)\n";
	}
	$out .= "\texten => _X.,1,SET(myClusterOclo=\${DB($clst/STATE)})\n";
	$out .= "\texten => _X.,n,GoToIf(\$[\"\${myClusterOclo}\" = \"CLOSED\"]?{$ctx}_closed,\${EXTEN},1:{$ctx}_open,\${EXTEN},1)\n";
}

$cos = $pdo->query("SELECT * FROM cos ORDER BY pkey")->fetchAll(PDO::FETCH_ASSOC);
$orideopen = [];
$orideclosed = [];
foreach ($cos as $mycos) {
	if ($mycos['orideopen'] === 'YES') {
		$orideopen[$mycos['pkey']] = 'YES';
	}
	if ($mycos['orideclosed'] === 'YES') {
		$orideclosed[$mycos['pkey']] = 'YES';
	}
}
foreach ($profiles as $prof) {
	$clst = $prof['cluster'];
	$ppkey = $prof['pkey'];
	$ctx = "COS_{$clst}_{$ppkey}";
	$out .= "[{$ctx}_open]\n";
	foreach ($orideopen as $key => $_v) {
		$out .= "\tinclude => $key\n";
	}
	$st = $pdo->prepare("SELECT cos_pkey FROM cos_profile_open WHERE cluster=? AND profile_pkey=? ORDER BY cos_pkey");
	$st->execute([$clst, $ppkey]);
	foreach ($st->fetchAll(PDO::FETCH_ASSOC) as $row) {
		if (empty($orideopen[$row['cos_pkey']])) {
			$out .= "\tinclude => {$row['cos_pkey']}\n";
		}
	}
	$out .= "\tinclude => {$ctx}_end\n";
	$out .= "[{$ctx}_closed]\n";
	foreach ($orideclosed as $key => $_v) {
		$out .= "\tinclude => $key\n";
	}
	$st = $pdo->prepare("SELECT cos_pkey FROM cos_profile_closed WHERE cluster=? AND profile_pkey=? ORDER BY cos_pkey");
	$st->execute([$clst, $ppkey]);
	foreach ($st->fetchAll(PDO::FETCH_ASSOC) as $row) {
		if (empty($orideclosed[$row['cos_pkey']])) {
			$out .= "\tinclude => {$row['cos_pkey']}\n";
		}
	}
	$out .= "\tinclude => {$ctx}_end\n";
	$out .= "[{$ctx}_end]\n";
	$out .= "\texten => _X.,1,GoTo($clst,\${EXTEN},1)\n\n";
}
foreach ($cos as $COS) {
	$out .= "[{$COS['pkey']}]\n";
	foreach (preg_split('/\s+/', trim((string) $COS['dialplan'])) as $plan) {
		if ($plan === '') {
			continue;
		}
		$out .= "\texten => $plan,1,Playtones(congestion)\n";
		$out .= "\texten => $plan,2,Hangup\n";
	}
}

file_put_contents("$workdir/extensions.snippet", $out);

$entry = preg_match_all('/^\[COS_[^\]_]+_[^\]_]+\]$/m', $out);
$open = preg_match_all('/^\[COS_[^\]]+_open\]$/m', $out);
$closed = preg_match_all('/^\[COS_[^\]]+_closed\]$/m', $out);
$end = preg_match_all('/^\[COS_[^\]]+_end\]$/m', $out);
expect("entry contexts == profiles ($entry == $nProf)", $entry === $nProf);
expect("open/closed/end == profiles", $open === $nProf && $closed === $nProf && $end === $nProf);
expect('no legacy opencos in emit', strpos($out, 'opencos') === false);
expect('bypass *X. present', strpos($out, '_*X.') !== false);
expect('park 901 bypass present', strpos($out, 'exten => 901,1,GoTo') !== false);
expect('emergency 999 bypass present', strpos($out, 'exten => 999,1,GoTo') !== false);
expect('floor HR_Premium on every open', substr_count($out, "include => HR_Premium\n") >= ($nProf * 2));
expect('deny rule [Intl] present', strpos($out, "[Intl]\n") !== false);

// Staff profile includes Intl; Unrestricted does not (except via floor HR only)
$staff = $pdo->query("SELECT cos_profile FROM ipphone WHERE pkey='1001'")->fetchColumn();
$unrest = $pdo->query("SELECT cos_profile FROM ipphone WHERE pkey='1004'")->fetchColumn();
expect('Staff ≠ Unrestricted profile', $staff && $unrest && $staff !== $unrest);
$staffOpen = $out;
// crude: Staff open section includes Intl; Unrestricted open does not list Intl (HR_Premium only from floor)
if (preg_match('/\[COS_tenanta_' . preg_quote($staff, '/') . '_open\](.*?)\[COS_tenanta_' . preg_quote($staff, '/') . '_closed\]/s', $out, $m)) {
	expect('Staff open includes Intl', strpos($m[1], 'include => Intl') !== false);
} else {
	expect('Staff open section found', false);
}
if (preg_match('/\[COS_tenanta_' . preg_quote($unrest, '/') . '_open\](.*?)\[COS_tenanta_' . preg_quote($unrest, '/') . '_closed\]/s', $out, $m)) {
	expect('Unrestricted open has floor not Intl', strpos($m[1], 'include => HR_Premium') !== false && strpos($m[1], 'include => Intl') === false);
} else {
	expect('Unrestricted open section found', false);
}

// cosstart OFF → phones would use tenant context (source has early return)
expect('cosstart OFF early-return in CoS', preg_match('/genExtensionsCoS\(\)[\s\S]*?cosstart[\s\S]*?!= "ON"/', $src) === 1
	|| preg_match("/genExtensionsCoS\(\)[\s\S]*?cosstart[\s\S]*?!= 'ON'/", $src) === 1
	|| strpos($src, "cosstart'] ?? '') != \"ON\"") !== false);

array_map('unlink', glob("$workdir/*") ?: []);
@rmdir($workdir);

if ($fail > 0) {
	fwrite(STDERR, "FAILED $fail check(s)\n");
	exit(1);
}
echo "PASS: genclass-cos-profiles-test\n";
exit(0);
