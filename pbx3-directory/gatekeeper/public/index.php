<?php

declare(strict_types=1);

/**
 * PBX3 fleet gatekeeper — registrar + move job APIs (S8.10).
 * Sole writer for catalog and tenants meta.json objects in S3.
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\CatalogReconcile;
use Pbx3\Gatekeeper\DidInventory;
use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\Http\JsonResponse;
use Pbx3\Gatekeeper\InstanceEdgeProvision;
use Pbx3\Gatekeeper\S3Presign;
use Pbx3\Gatekeeper\S3RecordingsPresign;
use Pbx3\Gatekeeper\S3Registrar;
use Pbx3\Gatekeeper\SbcFleetClient;
use Pbx3\Gatekeeper\SbcSetidGuard;
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

    // S10.6 — fleet user manage (fleet_admin only)
    if ($method === 'GET' && $path === '/api/v1/fleet-users') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        JsonResponse::send(200, [
            'users' => UserStore::listUsers(),
            'ability_vocab' => FleetAbilities::ALL,
        ]);
    }

    if ($method === 'POST' && $path === '/api/v1/fleet-users') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $email = is_string($body['email'] ?? null) ? $body['email'] : '';
        $password = is_string($body['password'] ?? null) ? $body['password'] : '';
        $name = is_string($body['name'] ?? null) ? $body['name'] : '';
        $abilities = isset($body['abilities']) && is_array($body['abilities']) ? $body['abilities'] : null;
        JsonResponse::send(201, UserStore::createUser($email, $password, $name, $abilities));
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/fleet-users/(\d+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $patch = [];
        if (array_key_exists('name', $body)) {
            $patch['name'] = is_string($body['name']) ? $body['name'] : '';
        }
        if (array_key_exists('password', $body) && is_string($body['password'])) {
            $patch['password'] = $body['password'];
        }
        if (array_key_exists('abilities', $body)) {
            $patch['abilities'] = is_array($body['abilities']) ? $body['abilities'] : [];
        }
        JsonResponse::send(200, UserStore::updateUser((int) $m[1], $patch));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/fleet-users/(\d+)/disable$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $actorId = Auth::isBreakGlass() ? null : (Auth::user()['id'] ?? null);
        JsonResponse::send(200, UserStore::disableUser(
            (int) $m[1],
            is_int($actorId) ? $actorId : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/fleet-users/(\d+)/enable$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        JsonResponse::send(200, UserStore::enableUser((int) $m[1]));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/fleet-users/(\d+)/revoke-sessions$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $revoked = UserStore::revokeAllTokensForUser((int) $m[1]);
        $user = UserStore::findById((int) $m[1]);
        if ($user === null) {
            throw new \RuntimeException('User not found', 404);
        }
        JsonResponse::send(200, ['ok' => true, 'revoked' => $revoked, 'user' => $user]);
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

    // S10.5 — catalog DID ownership (HoR). List = read; assign/release = fleet_edge.
    if ($method === 'GET' && $path === '/api/v1/dids') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, (new DidInventory($registrar))->listAll());
    }

    if ($method === 'POST' && $path === '/api/v1/dids/assign') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new DidInventory($registrar))->assign(is_array($body) ? $body : []));
    }

    if ($method === 'POST' && $path === '/api/v1/dids/release') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new DidInventory($registrar))->release(is_array($body) ? $body : []));
    }

    if ($method === 'POST' && $path === '/api/v1/dids/project') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $inv = new DidInventory($registrar);
        $tenant = isset($body['tenant_shortuid']) && is_string($body['tenant_shortuid'])
            ? strtolower(trim($body['tenant_shortuid']))
            : null;
        $filter = ($tenant !== null && $tenant !== '') ? [$tenant] : null;
        JsonResponse::send(200, $inv->projectToSbc(
            new SbcFleetClient(),
            $filter,
            ! empty($body['dry_run'])
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenants/([a-z0-9]+)/register-domain$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::EDGE);
        JsonResponse::send(200, (new DidInventory($registrar))->registerTenantDomain(
            new SbcFleetClient(),
            $m[1]
        ));
    }

    // S10.4 — catalog ↔ SBC domain.setid drift + optional force-project (Rule 13)
    if ($method === 'GET' && $path === '/api/v1/reconcile') {
        Auth::requireAbility(FleetAbilities::EDGE);
        JsonResponse::send(200, (new CatalogReconcile($registrar, new SbcFleetClient()))->report());
    }

    if ($method === 'POST' && $path === '/api/v1/reconcile/project') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new CatalogReconcile($registrar, new SbcFleetClient()))->project(
            is_array($body) ? $body : []
        ));
    }

    if ($method === 'GET' && $path === '/api/v1/sbc/dispatcher-sets') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, ['sets' => (new SbcFleetClient())->listDispatcherSets()]);
    }

    if ($method === 'POST' && $path === '/api/v1/instances') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $body = SbcSetidGuard::applyToBody(is_array($body) ? $body : [], new SbcFleetClient());
        $actor = Auth::user()['email'] ?? null;
        if (is_string($actor) && $actor !== '' && ! isset($body['updated_by'])) {
            $body['updated_by'] = $actor;
        }
        JsonResponse::send(201, $registrar->registerInstance($body));
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $body = SbcSetidGuard::applyToBody(is_array($body) ? $body : [], new SbcFleetClient());
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

    if ($method === 'POST' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)/provision-edge$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $actor = Auth::user()['email'] ?? null;
        if (is_string($actor) && $actor !== '') {
            $body['updated_by'] = $actor;
        }
        JsonResponse::send(200, InstanceEdgeProvision::provision(
            $registrar,
            new SbcFleetClient(),
            $m[1],
            $body
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
        $actor = Auth::user()['email'] ?? null;
        if (is_string($actor) && $actor !== '' && empty($body['created_by'])) {
            $body['created_by'] = $actor;
        }
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

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/abort$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $runner->abort(
            $m[1],
            is_string($shortuid) ? $shortuid : null,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/retry$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $runner->retry(
            $m[1],
            is_string($shortuid) ? $shortuid : null,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-moves/([A-Za-z0-9_-]+)/rollback$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $runner->rollback(
            $m[1],
            is_string($shortuid) ? $shortuid : null,
            is_string($actor) ? $actor : null
        ));
    }

    JsonResponse::send(404, ['error' => 'Not found', 'path' => $path]);
} catch (Throwable $e) {
    $code = (int) ($e->getCode() ?: 0);
    if ($e instanceof InvalidArgumentException && ($code < 400 || $code > 599)) {
        $code = 422;
    }
    if ($code < 400 || $code > 599) {
        $code = 500;
    }
    JsonResponse::send($code, ['error' => $e->getMessage()]);
}
