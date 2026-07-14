<?php

declare(strict_types=1);

/**
 * PBX3 fleet gatekeeper — registrar + move job APIs (S8.10).
 * Sole writer for catalog and tenants meta.json objects in S3.
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\Http\JsonResponse;
use Pbx3\Gatekeeper\S3Presign;
use Pbx3\Gatekeeper\S3Registrar;
use Pbx3\Gatekeeper\TenantMoveJobStore;
use Pbx3\Gatekeeper\TenantMoveRunner;

Env::load(dirname(__DIR__).'/.env');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = rtrim($path, '/') ?: '/';

if ($method === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
    header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
    http_response_code(204);
    exit;
}

try {
    if ($path === '/health') {
        JsonResponse::send(200, ['status' => 'ok']);
    }

    Auth::requireBearer();

    $registrar = new S3Registrar();
    $presign = new S3Presign();
    $jobs = new TenantMoveJobStore();
    $runner = new TenantMoveRunner($jobs, $presign, $registrar);

    if ($method === 'GET' && $path === '/api/v1/catalog') {
        JsonResponse::send(200, $registrar->getCatalog());
    }

    if ($method === 'GET' && $path === '/api/v1/tenants') {
        JsonResponse::send(200, ['tenants' => $registrar->listTenants()]);
    }

    if ($method === 'POST' && $path === '/api/v1/instances') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(201, $registrar->registerInstance($body));
    }

    if ($method === 'POST' && $path === '/api/v1/tenants') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(201, $registrar->registerTenant($body));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenants/([a-z0-9]+)/move$#', $path, $m)) {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, $registrar->moveTenant($m[1], $body));
    }

    if ($method === 'POST' && $path === '/api/v1/s3/presign') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, $presign->create($body));
    }

    if ($method === 'POST' && $path === '/api/v1/tenant-moves') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(201, $jobs->create($body));
    }

    if ($method === 'GET' && $path === '/api/v1/tenant-moves') {
        $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 50;
        JsonResponse::send(200, ['jobs' => $jobs->list($limit)]);
    }

    if ($method === 'GET' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)$#', $path, $m)) {
        $shortuid = $_GET['tenant'] ?? null;
        JsonResponse::send(200, $jobs->get($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/run$#', $path, $m)) {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? ($_GET['tenant'] ?? null);
        JsonResponse::send(200, $runner->runUntilGate($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/advance$#', $path, $m)) {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $short = is_string($shortuid) ? $shortuid : null;

        if (! empty($body['confirm'])) {
            JsonResponse::send(200, $runner->confirm($m[1], (string) $body['confirm'], $short));
        }
        if (! empty($body['state'])) {
            JsonResponse::send(200, $jobs->patchState($m[1], $body, $short));
        }
        JsonResponse::send(200, $runner->runUntilGate($m[1], $short));
    }

    JsonResponse::send(404, ['error' => 'Not found', 'path' => $path]);
} catch (Throwable $e) {
    $code = (int) ($e->getCode() ?: 500);
    if ($code < 400 || $code > 599) {
        $code = 500;
    }
    JsonResponse::send($code, ['error' => $e->getMessage()]);
}
