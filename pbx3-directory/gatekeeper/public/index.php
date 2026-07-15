<?php

declare(strict_types=1);

/**
 * PBX3 fleet gatekeeper — registrar + move job APIs (S8.10).
 * Sole writer for catalog and tenants meta.json objects in S3.
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\Http\JsonResponse;
use Pbx3\Gatekeeper\S3Presign;
use Pbx3\Gatekeeper\S3RecordingsPresign;
use Pbx3\Gatekeeper\S3Registrar;
use Pbx3\Gatekeeper\TenantMoveJobStore;
use Pbx3\Gatekeeper\TenantMoveRunner;
use Pbx3\Gatekeeper\UserStore;

Env::load(dirname(__DIR__).'/.env');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = rtrim($path, '/') ?: '/';

if ($method === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
    header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
    http_response_code(204);
    exit;
}

try {
    if ($path === '/health') {
        JsonResponse::send(200, ['status' => 'ok']);
    }

    // Public auth endpoints (infrastructure — no Bearer required)
    if ($method === 'POST' && $path === '/api/v1/auth/login') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $email = is_string($body['email'] ?? null) ? $body['email'] : '';
        $password = is_string($body['password'] ?? null) ? $body['password'] : '';
        JsonResponse::send(200, UserStore::login($email, $password));
    }

    if ($method === 'GET' && $path === '/api/v1/auth/status') {
        JsonResponse::send(200, [
            'auth' => 'fleet-user-or-break-glass',
            'users_configured' => UserStore::userCount() > 0,
            'login' => '/api/v1/auth/login',
        ]);
    }

    Auth::requireBearer();

    if ($method === 'GET' && $path === '/api/v1/auth/me') {
        $user = Auth::user();
        JsonResponse::send(200, [
            'user' => $user === null ? null : [
                'id' => $user['id'],
                'email' => $user['email'],
                'name' => $user['name'],
                'abilities' => $user['abilities'] ?? [],
            ],
            'abilities' => Auth::effectiveAbilities(),
            'break_glass' => Auth::isBreakGlass(),
        ]);
    }

    if ($method === 'POST' && $path === '/api/v1/auth/logout') {
        if (! Auth::isBreakGlass()) {
            UserStore::revokeToken(Auth::bearerToken());
        }
        JsonResponse::send(200, ['ok' => true]);
    }

    $registrar = new S3Registrar();
    $presign = new S3Presign();
    $jobs = new TenantMoveJobStore();
    $runner = new TenantMoveRunner($jobs, $presign, $registrar);

    if ($method === 'GET' && $path === '/api/v1/catalog') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, $registrar->getCatalog());
    }

    if ($method === 'GET' && $path === '/api/v1/tenants') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, ['tenants' => $registrar->listTenants()]);
    }

    if ($method === 'POST' && $path === '/api/v1/instances') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        if (is_string($actor) && $actor !== '' && ! isset($body['updated_by'])) {
            $body['updated_by'] = $actor;
        }
        JsonResponse::send(201, $registrar->registerInstance($body));
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $registrar->patchInstance(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)/decommission$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $registrar->decommissionInstance(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && $path === '/api/v1/tenants') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(201, $registrar->registerTenant($body));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenants/([a-z0-9]+)/move$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, $registrar->moveTenant($m[1], $body));
    }

    if ($method === 'POST' && $path === '/api/v1/s3/presign') {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, $presign->create($body));
    }

    // S7 — dedicated recordings bucket (never org/catalog). Scoped tenants/{shortuid}/recordings/*
    // Node agents typically use break-glass (fleet_admin).
    if ($method === 'POST' && $path === '/api/v1/s3/presign-recordings') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new S3RecordingsPresign())->create($body));
    }

    if ($method === 'POST' && $path === '/api/v1/tenant-moves') {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(201, $jobs->create($body));
    }

    if ($method === 'GET' && $path === '/api/v1/tenant-moves') {
        Auth::requireAbility(FleetAbilities::READ);
        $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 50;
        JsonResponse::send(200, ['jobs' => $jobs->list($limit)]);
    }

    if ($method === 'GET' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        $shortuid = $_GET['tenant'] ?? null;
        JsonResponse::send(200, $jobs->get($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/run$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? ($_GET['tenant'] ?? null);
        JsonResponse::send(200, $runner->runUntilGate($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/advance$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
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
