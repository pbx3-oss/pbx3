#!/usr/bin/env php
<?php
/**
 * Home provision entry (Phase A1).
 *
 * CLI:  php device.php <mac>
 * HTTP: later wired to :41363 (A5). For now callable under php-cli / php-fpm once routed.
 *
 * Uses instance sqlite + PROVISION_STREAMS. Fail-closed: unknown / duplicate MAC → 404.
 */

$optRoot = getenv('PBX3_ROOT');
if ($optRoot === false || $optRoot === '') {
	$optRoot = '/opt/pbx3';
}

$config = $optRoot . '/php/config.php';
$kernel = $optRoot . '/php/classes/ProvisionKernel.php';

// Dev / package-tree fallback when not installed under /opt/pbx3.
if (!is_readable($config)) {
	$here = dirname(__DIR__, 2); // …/opt/pbx3 (this file lives in php/provisioning/)
	$config = $here . '/php/config.php';
	$kernel = $here . '/php/classes/ProvisionKernel.php';
	$optRoot = $here;
}

if (!is_readable($config) || !is_readable($kernel)) {
	fwrite(STDERR, "provision: missing config or ProvisionKernel under $optRoot\n");
	exit(1);
}

require_once $config;
require_once $kernel;

$dbPath = defined('SYSDB') ? SYSDB : ($optRoot . '/db/sqlite.db');
if (getenv('PBX_SQLITE')) {
	$dbPath = getenv('PBX_SQLITE');
}

$streamsDir = defined('PROVISION_STREAMS') ? PROVISION_STREAMS : ($optRoot . '/provisioning/streams');
if (getenv('PBX3_PROVISION_STREAMS')) {
	$streamsDir = getenv('PBX3_PROVISION_STREAMS');
}

$cli = (PHP_SAPI === 'cli');
$method = $cli ? 'GET' : (isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET');
$uri = $cli ? '' : (isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : '');
$query = $cli ? array() : $_GET;

if ($cli) {
	if ($argc < 2) {
		fwrite(STDERR, "Usage: php device.php <mac>|--uri <path>\n");
		exit(2);
	}
	if ($argv[1] === '--uri' && isset($argv[2])) {
		$uri = $argv[2];
	} else {
		$query = array('mac' => $argv[1]);
	}
}

$parsed = pbx3_provision_parse_request($method, $uri, $query);

try {
	$db = new PDO('sqlite:' . $dbPath);
	$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (Exception $e) {
	if ($cli) {
		fwrite(STDERR, "DB open failed: " . $e->getMessage() . "\n");
		exit(1);
	}
	header('HTTP/1.0 404 Not Found');
	echo "Not Found (404)\n";
	exit;
}

$globals = array();
try {
	$row = $db->query('SELECT * FROM globals LIMIT 1')->fetch(PDO::FETCH_ASSOC);
	if (is_array($row)) {
		$globals = $row;
	}
} catch (Exception $e) {
	// leave empty — substitute uses defaults
}

$extra = array(
	'localip' => '127.0.0.1',
	'registrar' => '127.0.0.1',
);
// A3 will set fleet vs solo registrar; A1 leaves placeholder host.

$result = pbx3_provision_render($db, $parsed, $streamsDir, $globals, $extra);

if ($cli) {
	if (!$result['ok'] && $result['status'] === 404) {
		fwrite(STDERR, "404 " . $result['reason'] . "\n");
		fwrite(STDOUT, $result['body']);
		exit(1);
	}
	fwrite(STDOUT, $result['body']);
	exit(0);
}

if ($result['status'] === 404) {
	header('HTTP/1.0 404 Not Found');
	echo $result['body'];
	exit;
}
if ($result['status'] === 200 && $result['reason'] === 'put_noop') {
	header('HTTP/1.0 200 OK');
	echo $result['body'];
	exit;
}

header('Content-type: text/plain');
echo $result['body'];
