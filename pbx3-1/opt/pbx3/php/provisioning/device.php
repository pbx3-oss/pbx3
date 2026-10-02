<?php
/**
 * Home provision entry (Phase A).
 *
 * No shebang — under php-fpm anything before <?php is emitted to the phone body.
 *
 * CLI:  php device.php <mac>
 *       php device.php --uri /provisioning/<mac>.cfg
 * HTTP: nginx :41363 → this script (install-provision-listener.sh / A5).
 *       Solo = HTTPS; fleet home = HTTP (edge terminates TLS).
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
	// STDERR is undefined under php-fpm; php://stderr works in both CLI and FPM.
	file_put_contents('php://stderr', "provision: missing config or ProvisionKernel under $optRoot\n");
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

$auditPath = defined('PROVISION_AUDIT_LOG') ? PROVISION_AUDIT_LOG : ($optRoot . '/var/log/provision-audit.log');
if (getenv('PBX3_PROVISION_AUDIT')) {
	$auditPath = getenv('PBX3_PROVISION_AUDIT');
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
	// leave empty
}

$hosts = pbx3_provision_resolve_hosts($db, $globals);
$extra = array(
	'localip' => $hosts['localip'],
	'outbound' => $hosts['outbound'],
	'outbound_enable' => $hosts['outbound_enable'],
	'outbound_hostport' => $hosts['outbound_hostport'],
	'provurl' => $hosts['provurl'],
);

$result = pbx3_provision_render($db, $parsed, $streamsDir, $globals, $extra);

if (!empty($result['ok']) && (int) $result['status'] === 200 && $result['reason'] === 'mac') {
	pbx3_provision_after_success($db, $result, array(
		'mac' => isset($parsed['mac']) ? $parsed['mac'] : null,
		'remote_addr' => isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : ($cli ? 'cli' : null),
	), $auditPath);
}

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
