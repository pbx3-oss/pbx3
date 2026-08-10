<?php
/**
 * dumper-escape-test.php
 *
 * Regression test for PRE_RELEASE_SAFETY_DEBT item 8 (dumper.php):
 *   - falsy-but-meaningful column values (0, '', false) must NOT be
 *     silently dropped from the reloader dump.
 *   - values must be single-quote escaped before being interpolated into
 *     the SQL INSERT literal (O'Brien -> O''Brien), so the dump is safe to
 *     replay and doesn't break on customer data.
 *
 * This test extracts the real helper functions (find_col, sql_escape,
 * build_row_insert_parts) directly out of the shipped dumper.php source via
 * a tiny tokenizer, then unit-tests them in isolation. It deliberately does
 * NOT `require` dumper.php directly, because that file executes real dump
 * logic (config, DB connect, filesystem writes under /opt/pbx3) as soon as
 * it's loaded — extraction lets us test the exact production code without
 * duplicating (and risking drift from) its logic.
 *
 * Run: php dumper-escape-test.php
 * Exit 0 on pass, 1 on failure.
 */

$dumperPath = __DIR__ . '/../../php/utilities/dumper.php';
if (!file_exists($dumperPath)) {
	fwrite(STDERR, "FAIL: dumper.php not found at $dumperPath\n");
	exit(1);
}
$source = file_get_contents($dumperPath);

/**
 * extract_function
 * Pulls the full source of a top-level `function $name(...) { ... }`
 * definition out of $source using brace matching, so the test always runs
 * against exactly what's shipped (no copy/paste drift).
 */
function extract_function($source, $name) {
	if (!preg_match('/function\s+' . preg_quote($name, '/') . '\s*\([^)]*\)\s*\{/', $source, $m, PREG_OFFSET_CAPTURE)) {
		return null;
	}
	$start = $m[0][1];
	$bracePos = $start + strlen($m[0][0]) - 1; // position of the opening '{'
	$depth = 0;
	$len = strlen($source);
	for ($i = $bracePos; $i < $len; $i++) {
		if ($source[$i] === '{') {
			$depth++;
		} elseif ($source[$i] === '}') {
			$depth--;
			if ($depth === 0) {
				return substr($source, $start, $i - $start + 1);
			}
		}
	}
	return null;
}

$fails = 0;
function ok($msg) { echo "ok: $msg\n"; }
function fail($msg) {
	global $fails;
	$fails++;
	fwrite(STDERR, "FAIL: $msg\n");
}

foreach (array('find_col', 'sql_escape', 'build_row_insert_parts') as $fn) {
	$code = extract_function($source, $fn);
	if ($code === null) {
		fail("could not extract function $fn from dumper.php (source shape changed?)");
		continue;
	}
	eval($code);
	if (!function_exists($fn)) {
		fail("eval of extracted $fn did not define it");
	}
}

if ($fails) {
	fwrite(STDERR, "Aborting: helper extraction failed, cannot continue.\n");
	exit(1);
}

// ---- sql_escape ----

if (sql_escape("O'Brien") !== "O''Brien") {
	fail("sql_escape must double single quotes: got '" . sql_escape("O'Brien") . "'");
} else {
	ok("sql_escape escapes single quotes (O'Brien -> O''Brien)");
}

if (sql_escape("it's a 'test'") !== "it''s a ''test''") {
	fail("sql_escape must escape all quotes in a value");
} else {
	ok("sql_escape escapes multiple quotes");
}

if (sql_escape(0) !== "0") {
	fail("sql_escape(0) should stringify to '0', got '" . sql_escape(0) . "'");
} else {
	ok("sql_escape preserves 0");
}

if (sql_escape('') !== '') {
	fail("sql_escape('') should remain empty string");
} else {
	ok("sql_escape preserves empty string");
}

// ---- build_row_insert_parts: falsy-but-meaningful values are NOT skipped ----

$colrows = array(
	array('name' => 'id'),
	array('name' => 'pkey'),
	array('name' => 'active'),        // 0 (falsy int) - must be included
	array('name' => 'notes'),         // '' (falsy string) - must be included
	array('name' => 'lastname'),      // contains a quote - must be escaped
	array('name' => 'flag'),          // false (falsy bool) - must be included
	array('name' => 'deleted_at'),    // NULL - must be skipped (true absence)
	array('name' => 'z_updated'),     // timestamp column - must be skipped
	array('name' => 'secret'),        // dropped column - must be skipped
);

$row = array(
	'id'         => 'kAbc123',
	'pkey'       => 'ext100',
	'active'     => 0,
	'notes'      => '',
	'lastname'   => "O'Brien",
	'flag'       => false,
	'deleted_at' => null,
	'z_updated'  => '2026-01-01 00:00:00',
	'secret'     => 'shh',
);

$drops = array('mytable' => array('secret'));

list($cols, $vals) = build_row_insert_parts($colrows, $row, 'mytable', $drops);

$colList = explode(',', $cols);

if (!in_array('active', $colList)) {
	fail("column 'active' with value 0 was dropped (falsy-skip bug) — cols=$cols");
} else {
	ok("column with value 0 is included");
}

if (!in_array('notes', $colList)) {
	fail("column 'notes' with value '' was dropped (falsy-skip bug) — cols=$cols");
} else {
	ok("column with value '' is included");
}

if (!in_array('flag', $colList)) {
	fail("column 'flag' with value false was dropped (falsy-skip bug) — cols=$cols");
} else {
	ok("column with value false is included");
}

if (in_array('deleted_at', $colList)) {
	fail("column 'deleted_at' with value NULL should be skipped — cols=$cols");
} else {
	ok("column with true NULL value is skipped");
}

if (in_array('z_updated', $colList)) {
	fail("z_ timestamp column should still be skipped — cols=$cols");
} else {
	ok("z_ timestamp column still skipped");
}

if (in_array('secret', $colList)) {
	fail("dropped column 'secret' should be skipped — cols=$cols");
} else {
	ok("explicitly dropped column still skipped");
}

if (strpos($vals, "O''Brien") === false) {
	fail("lastname value not escaped in VALDATA: $vals");
} else {
	ok("value with embedded quote is escaped in generated VALDATA");
}

// Build the actual INSERT text the way dumper.php does, and sanity check it.
$insertSql = "INSERT OR IGNORE INTO mytable(" . $cols . ") values (" . $vals . ");";

$valTokens = explode(',', $vals);

if (!in_array("'0'", $valTokens, true)) {
	fail("generated INSERT should contain the literal 0 value: $insertSql");
} else {
	ok("generated INSERT SQL contains 0");
}

if (!in_array("''", $valTokens, true)) {
	fail("generated INSERT should contain an empty string literal: $insertSql");
} else {
	ok("generated INSERT SQL contains an empty string literal");
}

if (!in_array("'O''Brien'", $valTokens, true)) {
	fail("generated INSERT should contain escaped quote: $insertSql");
} else {
	ok("generated INSERT SQL contains escaped O''Brien");
}

echo "\nGenerated INSERT: $insertSql\n\n";

if ($fails > 0) {
	fwrite(STDERR, "\n$fails assertion(s) FAILED\n");
	exit(1);
}

echo "PASS: dumper-escape-test ($fails failures)\n";
exit(0);
