<?php
/**
 * genclass-appl-cluster-test.php
 *
 * Regression test for PRE_RELEASE_SAFETY_DEBT item 9 (GenClass.php):
 *   genExtensionsEndpoints() builds the per-cluster `appl` include list with
 *   `SELECT * FROM appl WHERE cluster='<key>' ORDER BY pkey`. Post-normalize,
 *   appl.cluster stores the tenant's shortuid, not its KSUID id. Querying by
 *   `$row['id']` therefore returns nothing and the tenant's custom app/DDI
 *   dialplan `include =>` lines silently disappear.
 *
 * GenClass needs Asterisk + full instance config to actually invoke, so per
 * the task's fallback this test:
 *   1. Extracts the literal SQL template for the appl-by-cluster query
 *      straight out of the shipped GenClass.php source (regex on the
 *      `genExtensionsEndpoints` method), so the test tracks the real code
 *      and can't silently drift.
 *   2. Asserts that template keys off `$row['shortuid']`, not `$row['id']`.
 *   3. Builds a tiny in-memory sqlite fixture (cluster + appl tables) that
 *      mirrors the post-normalize shape (appl.cluster = tenant shortuid,
 *      distinct from tenant.id) and runs the *actual extracted SQL* against
 *      it, asserting it returns the tenant's appl rows (proving the
 *      `include =>` line would be generated) and that using the old `id`
 *      key returns nothing (proving the historical bug/regression shape).
 *
 * Run: php genclass-appl-cluster-test.php
 * Exit 0 on pass, 1 on failure.
 */

$genClassPath = __DIR__ . '/../../php/classes/GenClass.php';
if (!file_exists($genClassPath)) {
	fwrite(STDERR, "FAIL: GenClass.php not found at $genClassPath\n");
	exit(1);
}
$source = file_get_contents($genClassPath);

$fails = 0;
function ok($msg) { echo "ok: $msg\n"; }
function fail($msg) {
	global $fails;
	$fails++;
	fwrite(STDERR, "FAIL: $msg\n");
}

// ---- 1. Extract the appl-by-cluster query from genExtensionsEndpoints() ----

if (!preg_match('/private function genExtensionsEndpoints\(\)\s*\{/', $source, $m, PREG_OFFSET_CAPTURE)) {
	fail("could not locate genExtensionsEndpoints() in GenClass.php (source shape changed?)");
	exit(1);
}
$methodStart = $m[0][1];
$bracePos = $methodStart + strlen($m[0][0]) - 1;
$depth = 0;
$methodEnd = null;
$len = strlen($source);
for ($i = $bracePos; $i < $len; $i++) {
	if ($source[$i] === '{') {
		$depth++;
	} elseif ($source[$i] === '}') {
		$depth--;
		if ($depth === 0) {
			$methodEnd = $i;
			break;
		}
	}
}
if ($methodEnd === null) {
	fail("could not find end of genExtensionsEndpoints() body");
	exit(1);
}
$methodBody = substr($source, $methodStart, $methodEnd - $methodStart + 1);

if (!preg_match('/\$sql\s*=\s*"SELECT \* FROM appl WHERE cluster=\'"\s*\.\s*\$row\[\'(\w+)\'\]\s*\.\s*"\' ORDER BY pkey";/', $methodBody, $sqlMatch)) {
	fail("could not find the appl-by-cluster SQL assembly line in genExtensionsEndpoints()");
	exit(1);
}
$keyUsed = $sqlMatch[1];

if ($keyUsed !== 'shortuid') {
	fail("appl-by-cluster query must key off \$row['shortuid'] (post-normalize appl.cluster), got \$row['$keyUsed']");
} else {
	ok("genExtensionsEndpoints() appl query keys off \$row['shortuid']");
}

// ---- 2. Prove it end-to-end against a fixture DB using the extracted SQL shape ----

$dbFile = tempnam(sys_get_temp_dir(), 'genclass_appl_test_');
unlink($dbFile); // PDO sqlite wants to create it fresh
$dbh = new PDO('sqlite:' . $dbFile);
$dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$dbh->exec("CREATE TABLE cluster (id TEXT PRIMARY KEY, pkey TEXT, shortuid TEXT)");
$dbh->exec("CREATE TABLE appl (pkey TEXT, cluster TEXT, span TEXT)");

// Post-normalize shape: id (KSUID) and shortuid are deliberately different,
// and appl.cluster is populated with the tenant's shortuid.
$tenantId = 'k1a2b3c4d5e6f7g8h9i0j1k2l3m';
$tenantShortuid = 'abcd12';
$dbh->exec("INSERT INTO cluster (id, pkey, shortuid) VALUES ('$tenantId', 'default', '$tenantShortuid')");
$dbh->exec("INSERT INTO appl (pkey, cluster, span) VALUES ('customapp1', '$tenantShortuid', 'Internal')");
$dbh->exec("INSERT INTO appl (pkey, cluster, span) VALUES ('customapp2', '$tenantShortuid', 'Both')");

$row = $dbh->query("SELECT * FROM cluster WHERE pkey='default'")->fetch(PDO::FETCH_ASSOC);

// Run the *actual* production SQL template (as extracted above) with the
// current (fixed) key.
$fixedSql = "SELECT * FROM appl WHERE cluster='" . $row[$keyUsed] . "' ORDER BY pkey";
$fixedRows = $dbh->query($fixedSql)->fetchAll(PDO::FETCH_ASSOC);

if (count($fixedRows) !== 2) {
	fail("fixed query (keyed on '$keyUsed') should return 2 appl rows for the tenant, got " . count($fixedRows) . " — dialplan include => lines would be missing");
} else {
	ok("fixed query returns the tenant's appl rows (dialplan include => lines would be generated)");
}

$applPkeys = array_column($fixedRows, 'pkey');
if (!in_array('customapp1', $applPkeys) || !in_array('customapp2', $applPkeys)) {
	fail("expected both customapp1 and customapp2 in appl results, got: " . implode(',', $applPkeys));
} else {
	ok("expected appl pkeys (customapp1, customapp2) present in result set");
}

// Demonstrate the historical bug shape: querying by id (KSUID) on
// post-normalize data returns nothing.
$buggySql = "SELECT * FROM appl WHERE cluster='" . $row['id'] . "' ORDER BY pkey";
$buggyRows = $dbh->query($buggySql)->fetchAll(PDO::FETCH_ASSOC);

if (count($buggyRows) !== 0) {
	fail("sanity check: querying appl by tenant KSUID id should return 0 rows post-normalize (fixture invalid)");
} else {
	ok("querying by id (old bug) reproduces the empty-includes regression on post-normalize data");
}

unlink($dbFile);

if ($fails > 0) {
	fwrite(STDERR, "\n$fails assertion(s) FAILED\n");
	exit(1);
}

echo "PASS: genclass-appl-cluster-test ($fails failures)\n";
exit(0);
