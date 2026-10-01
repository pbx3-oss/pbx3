<?php

declare(strict_types=1);

/**
 * PBX3 fleet gatekeeper — registrar + move job APIs (S8.10).
 * Sole writer for catalog and tenants meta.json objects in S3.
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\CatalogHealthOverlay;
use Pbx3\Gatekeeper\CatalogIntegrityException;
use Pbx3\Gatekeeper\CatalogReconcile;
use Pbx3\Gatekeeper\DialCohortJobStore;
use Pbx3\Gatekeeper\DialCohortMaterialiseRunner;
use Pbx3\Gatekeeper\DialCohortStore;
use Pbx3\Gatekeeper\DidInventory;
use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\Http\JsonResponse;
use Pbx3\Gatekeeper\InstanceEdgeLifecycle;
use Pbx3\Gatekeeper\InstanceEdgeProvision;
use Pbx3\Gatekeeper\MacIndexStore;
use Pbx3\Gatekeeper\NodeFleetDialClient;
use Pbx3\Gatekeeper\NotifyDispatcher;
use Pbx3\Gatekeeper\OpsEventThrottle;
use Pbx3\Gatekeeper\S3Presign;
use Pbx3\Gatekeeper\S3RecordingsPresign;
use Pbx3\Gatekeeper\S3Registrar;
use Pbx3\Gatekeeper\SbcFleetClient;
use Pbx3\Gatekeeper\SbcSetidGuard;
use Pbx3\Gatekeeper\TenantDeleteJobStore;
use Pbx3\Gatekeeper\TenantDeleteRunner;
use Pbx3\Gatekeeper\TenantMoveJobStore;
use Pbx3\Gatekeeper\TenantMoveRunner;
use Pbx3\Gatekeeper\TenantProvisioner;
use Pbx3\Gatekeeper\UserStore;
use Pbx3\Gatekeeper\VelocityPolicyStore;

Env::load(dirname(__DIR__).'/.env');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = rtrim($path, '/') ?: '/';

if ($method === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
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

    if ($method === 'POST' && $path === '/api/v1/auth/2fa/verify') {
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $challengeId = is_string($body['challenge_id'] ?? null) ? $body['challenge_id'] : '';
        $code = is_string($body['code'] ?? null) ? $body['code'] : '';
        if ($challengeId === '' || $code === '') {
            throw new \InvalidArgumentException('challenge_id and code required', 422);
        }
        JsonResponse::send(200, UserStore::verifyTwoFactor($challengeId, $code));
    }

    if ($method === 'GET' && $path === '/api/v1/auth/status') {
        JsonResponse::send(200, [
            'auth' => 'fleet-user-or-break-glass',
            'users_configured' => UserStore::userCount() > 0,
            'login' => '/api/v1/auth/login',
            'two_factor_verify' => '/api/v1/auth/2fa/verify',
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
                'two_factor_enabled' => (bool) ($user['two_factor_enabled'] ?? false),
            ],
            'abilities' => Auth::effectiveAbilities(),
            'break_glass' => Auth::isBreakGlass(),
            'two_factor_enabled' => Auth::isBreakGlass()
                ? false
                : (bool) ($user['two_factor_enabled'] ?? false),
        ]);
    }

    if ($method === 'POST' && $path === '/api/v1/auth/logout') {
        if (! Auth::isBreakGlass()) {
            UserStore::revokeToken(Auth::bearerToken());
        }
        JsonResponse::send(200, ['ok' => true]);
    }

    if ($method === 'POST' && $path === '/api/v1/auth/2fa/setup') {
        if (Auth::isBreakGlass()) {
            throw new \RuntimeException('Break-glass cannot enroll TOTP', 422);
        }
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $password = is_string($body['password'] ?? null) ? $body['password'] : '';
        if ($password === '') {
            throw new \InvalidArgumentException('password required', 422);
        }
        $user = Auth::user();
        JsonResponse::send(200, UserStore::setupTwoFactor((int) ($user['id'] ?? 0), $password));
    }

    if ($method === 'POST' && $path === '/api/v1/auth/2fa/confirm') {
        if (Auth::isBreakGlass()) {
            throw new \RuntimeException('Break-glass cannot enroll TOTP', 422);
        }
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $code = is_string($body['code'] ?? null) ? $body['code'] : '';
        if ($code === '') {
            throw new \InvalidArgumentException('code required', 422);
        }
        $user = Auth::user();
        JsonResponse::send(200, UserStore::confirmTwoFactor((int) ($user['id'] ?? 0), $code));
    }

    if ($method === 'POST' && $path === '/api/v1/auth/2fa/disable') {
        if (Auth::isBreakGlass()) {
            throw new \RuntimeException('Break-glass cannot manage TOTP', 422);
        }
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $password = is_string($body['password'] ?? null) ? $body['password'] : '';
        $code = is_string($body['code'] ?? null) ? $body['code'] : '';
        if ($password === '') {
            throw new \InvalidArgumentException('password required', 422);
        }
        $user = Auth::user();
        JsonResponse::send(200, UserStore::disableTwoFactor((int) ($user['id'] ?? 0), $password, $code));
    }

    if ($method === 'POST' && $path === '/api/v1/auth/2fa/recovery') {
        if (Auth::isBreakGlass()) {
            throw new \RuntimeException('Break-glass cannot manage TOTP', 422);
        }
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $password = is_string($body['password'] ?? null) ? $body['password'] : '';
        $code = is_string($body['code'] ?? null) ? $body['code'] : '';
        if ($password === '' || $code === '') {
            throw new \InvalidArgumentException('password and code required', 422);
        }
        $user = Auth::user();
        JsonResponse::send(200, UserStore::regenerateRecoveryCodes((int) ($user['id'] ?? 0), $password, $code));
    }

    // Edge settings (SBC admin API URL — SQLite overrides env)
    if ($method === 'GET' && $path === '/api/v1/edge-settings') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, \Pbx3\Gatekeeper\ControlSettingsStore::edgeSettingsPublic());
    }

    if ($method === 'PATCH' && $path === '/api/v1/edge-settings') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            JsonResponse::send(400, ['error' => 'JSON body required']);
        }
        try {
            $settings = \Pbx3\Gatekeeper\ControlSettingsStore::patchEdgeSettings($body);
        } catch (\InvalidArgumentException $e) {
            JsonResponse::send(422, ['error' => $e->getMessage()]);
        }
        JsonResponse::send(200, $settings);
    }

    // SBC HA edge pairs (FO lab + future fleet edges)
    if ($method === 'GET' && $path === '/api/v1/edge-pairs') {
        Auth::requireAbility(FleetAbilities::READ);
        $pairs = \Pbx3\Gatekeeper\EdgePairStore::list();
        $out = [];
        foreach ($pairs as $pair) {
            $health = \Pbx3\Gatekeeper\EdgePairHealthStore::get((string) $pair['id']);
            $pair['health'] = $health === null ? null : [
                'reachable' => $health['reachable'],
                'consecutive_misses' => $health['consecutive_misses'],
                'last_ok_at' => $health['last_ok_at'],
                'last_probe_at' => $health['last_probe_at'],
                'last_rtt_ms' => $health['last_rtt_ms'],
            ];
            $out[] = $pair;
        }
        JsonResponse::send(200, ['edge_pairs' => $out]);
    }

    if ($method === 'POST' && $path === '/api/v1/edge-pairs') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            JsonResponse::send(400, ['error' => 'JSON body required']);
        }
        try {
            $pair = \Pbx3\Gatekeeper\EdgePairStore::create($body);
        } catch (\InvalidArgumentException $e) {
            JsonResponse::send(422, ['error' => $e->getMessage()]);
        } catch (\RuntimeException $e) {
            $code = (int) $e->getCode();
            JsonResponse::send($code >= 400 && $code < 600 ? $code : 500, ['error' => $e->getMessage()]);
        }
        JsonResponse::send(201, $pair);
    }

    if ($method === 'GET' && preg_match('#^/api/v1/edge-pairs/([^/]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        $pair = \Pbx3\Gatekeeper\EdgePairStore::get(rawurldecode($m[1]));
        if ($pair === null) {
            JsonResponse::send(404, ['error' => 'edge pair not found']);
        }
        $health = \Pbx3\Gatekeeper\EdgePairHealthStore::get((string) $pair['id']);
        $pair['health'] = $health === null ? null : [
            'reachable' => $health['reachable'],
            'consecutive_misses' => $health['consecutive_misses'],
            'last_ok_at' => $health['last_ok_at'],
            'last_probe_at' => $health['last_probe_at'],
            'last_rtt_ms' => $health['last_rtt_ms'],
        ];
        JsonResponse::send(200, $pair);
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/edge-pairs/([^/]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            JsonResponse::send(400, ['error' => 'JSON body required']);
        }
        try {
            $pair = \Pbx3\Gatekeeper\EdgePairStore::patch(rawurldecode($m[1]), $body);
        } catch (\InvalidArgumentException $e) {
            JsonResponse::send(422, ['error' => $e->getMessage()]);
        } catch (\RuntimeException $e) {
            $code = (int) $e->getCode();
            JsonResponse::send($code >= 400 && $code < 600 ? $code : 500, ['error' => $e->getMessage()]);
        }
        JsonResponse::send(200, $pair);
    }

    if ($method === 'DELETE' && preg_match('#^/api/v1/edge-pairs/([^/]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        try {
            \Pbx3\Gatekeeper\EdgePairStore::delete(rawurldecode($m[1]));
        } catch (\InvalidArgumentException $e) {
            JsonResponse::send(422, ['error' => $e->getMessage()]);
        } catch (\RuntimeException $e) {
            $code = (int) $e->getCode();
            JsonResponse::send($code >= 400 && $code < 600 ? $code : 500, ['error' => $e->getMessage()]);
        }
        JsonResponse::send(200, ['ok' => true]);
    }

    if ($method === 'POST' && preg_match('#^/api/v1/edge-pairs/([^/]+)/promote$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $pair = \Pbx3\Gatekeeper\EdgePairStore::get(rawurldecode($m[1]));
        if ($pair === null) {
            JsonResponse::send(404, ['error' => 'edge pair not found']);
        }
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $confirmStandbySip = ! empty($body['confirm_standby_sip_warning']);
        $promoter = \Pbx3\Gatekeeper\EdgePairPromoter::fromEnv();
        $standbySip = $promoter->probeStandbySip($pair);
        if (! $standbySip['ok'] && ! $confirmStandbySip) {
            JsonResponse::send(409, [
                'ok' => false,
                'needs_confirm' => true,
                'warning' => $standbySip['warning'] ?? 'Standby SIP not confirmed',
                'standby_sip' => $standbySip,
            ]);
        }
        $result = $promoter->promote($pair, true, $standbySip);
        $notify = NotifyDispatcher::fromEnv();
        if ($result['ok']) {
            $fresh = \Pbx3\Gatekeeper\EdgePairStore::get((string) $pair['id']) ?? $pair;
            $notify->notifyEdgePromoted($fresh, $result);
            JsonResponse::send(200, ['ok' => true, 'pair' => $fresh, 'result' => $result]);
        }
        $notify->notifyEdgePromoteFailed($pair, (string) ($result['error'] ?? 'unknown'));
        JsonResponse::send(502, ['ok' => false, 'error' => $result['error'] ?? 'promote failed', 'result' => $result]);
    }

    if ($method === 'POST' && preg_match('#^/api/v1/edge-pairs/([^/]+)/warm-sync$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $pair = \Pbx3\Gatekeeper\EdgePairStore::get(rawurldecode($m[1]));
        if ($pair === null) {
            JsonResponse::send(404, ['error' => 'edge pair not found']);
        }
        $sync = \Pbx3\Gatekeeper\EdgeWarmSync::fromEnv();
        $result = $sync->sync($pair);
        $fresh = \Pbx3\Gatekeeper\EdgePairStore::get((string) $pair['id']) ?? $pair;
        if ($result['ok']) {
            JsonResponse::send(200, ['ok' => true, 'pair' => $fresh, 'result' => $result]);
        }
        JsonResponse::send(502, [
            'ok' => false,
            'error' => $result['error'] ?? 'warm sync failed',
            'pair' => $fresh,
            'result' => $result,
        ]);
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
        $created = UserStore::createUser($email, $password, $name, $abilities);
        if (array_key_exists('notify_failures', $body) && (bool) $body['notify_failures']) {
            $created = UserStore::updateUser((int) $created['id'], ['notify_failures' => true]);
        }
        JsonResponse::send(201, $created);
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
        if (array_key_exists('notify_failures', $body)) {
            $patch['notify_failures'] = (bool) $body['notify_failures'];
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

    if ($method === 'POST' && preg_match('#^/api/v1/fleet-users/(\d+)/clear-2fa$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $cleared = UserStore::clearTwoFactorForUser((int) $m[1]);
        JsonResponse::send(200, ['ok' => true, 'user' => $cleared, 'revoked' => $cleared['revoked'] ?? 0]);
    }

    $registrar = new S3Registrar();
    $presign = new S3Presign();
    $jobs = new TenantMoveJobStore();
    $runner = new TenantMoveRunner($jobs, $presign, $registrar);
    $deleteJobs = new TenantDeleteJobStore();

    // C1/C3 — dial cohorts (UI: Site Groups) + materialise jobs (needed by Fleet Delete mesh prune).
    $dialCohorts = new DialCohortStore($registrar);
    $dialJobs = new DialCohortJobStore($registrar);
    $dialRunner = new DialCohortMaterialiseRunner($dialJobs, $registrar, new NodeFleetDialClient());
    $deleteRunner = new TenantDeleteRunner($deleteJobs, $registrar, new SbcFleetClient(), $dialCohorts, $dialRunner);
    $velocityPolicy = new VelocityPolicyStore($registrar);

    if ($method === 'GET' && $path === '/api/v1/velocity-policy') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, $velocityPolicy->get());
    }

    if ($method === 'PUT' && $path === '/api/v1/velocity-policy') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $velocityPolicy->put(
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'GET' && $path === '/api/v1/catalog') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, CatalogHealthOverlay::enrich($registrar->getCatalog()));
    }

    if ($method === 'POST' && $path === '/api/v1/catalog/tenant-home/rebuild') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        JsonResponse::send(200, $registrar->rebuildTenantHomeIndex());
    }

    if ($method === 'GET' && $path === '/api/v1/tenants') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, ['tenants' => $registrar->listTenants()]);
    }

    // C1/C3 — dial cohorts (UI: Site Groups) + materialise jobs.
    // ($dialCohorts / $dialRunner constructed above for Fleet Delete T2 mesh prune)

    if ($method === 'GET' && $path === '/api/v1/dial-cohorts') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, $dialCohorts->listIndex());
    }

    if ($method === 'POST' && $path === '/api/v1/dial-cohorts') {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(201, $dialCohorts->create(
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && $path === '/api/v1/catalog/dial-cohort-index/rebuild') {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        JsonResponse::send(200, $dialCohorts->rebuildIndex());
    }

    if ($method === 'POST' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/sync$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $dialRunner->syncNow(
            $m[1],
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'GET' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/jobs$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 20;
        JsonResponse::send(200, ['jobs' => $dialJobs->listForCohort($m[1], $limit)]);
    }

    if ($method === 'GET' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/jobs/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, $dialJobs->get($m[1], $m[2]));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/jobs/([A-Za-z0-9_-]+)/run$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $dialRunner->run($m[1], $m[2], is_string($actor) ? $actor : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/jobs/([A-Za-z0-9_-]+)/retry$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $dialRunner->retry($m[1], $m[2], is_string($actor) ? $actor : null));
    }

    if ($method === 'GET' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, $dialCohorts->get($m[1]));
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $dialCohorts->patch(
            $m[1],
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/decommission$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        $out = $dialCohorts->decommission(
            $m[1],
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        );
        $former = is_array($out['former_members'] ?? null) ? $out['former_members'] : [];
        if ($former !== [] && (! isset($body['materialise']) || ! empty($body['materialise']))) {
            try {
                $out['prune'] = $dialRunner->pruneCohortFromNodes($m[1], $former);
            } catch (\Throwable $e) {
                $out['prune_error'] = $e->getMessage();
            }
        }
        JsonResponse::send(200, $out);
    }

    if ($method === 'POST' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/members$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $actor = Auth::user()['email'] ?? null;
        $out = $dialCohorts->addMember(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        );
        if (! isset($body['materialise']) || ! empty($body['materialise'])) {
            $out['job'] = $dialRunner->syncNow(
                $m[1],
                ['reason' => 'add_member', 'prune_unmanaged' => $body['prune_unmanaged'] ?? true],
                is_string($actor) ? $actor : null
            );
        }
        JsonResponse::send(200, $out);
    }

    if ($method === 'DELETE' && preg_match('#^/api/v1/dial-cohorts/([A-Za-z0-9_-]+)/members/([a-z0-9]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $actor = Auth::user()['email'] ?? null;
        $qs = [];
        parse_str((string) (parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_QUERY) ?: ''), $qs);
        $materialise = ! isset($qs['materialise']) || $qs['materialise'] === '' || filter_var($qs['materialise'], FILTER_VALIDATE_BOOL);
        $out = $dialCohorts->removeMember(
            $m[1],
            $m[2],
            is_string($actor) ? $actor : null
        );
        if ($materialise) {
            $out['job'] = $dialRunner->syncNow(
                $m[1],
                ['reason' => 'remove_member'],
                is_string($actor) ? $actor : null
            );
            // Also prune managed rows for the removed tenant (no longer in cohort members list).
            try {
                $out['prune_removed'] = $dialRunner->pruneCohortFromNodes($m[1], [$m[2]]);
            } catch (\Throwable $e) {
                $out['prune_removed_error'] = $e->getMessage();
            }
        }
        JsonResponse::send(200, $out);
    }

    if ($method === 'PATCH' && preg_match('#^/api/v1/tenants/([a-z0-9]+)/routing-prefix$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::DIAL_COHORTS);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $actor = Auth::user()['email'] ?? null;
        $meta = $dialCohorts->setRoutingPrefix(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        );
        $cohortId = trim((string) ($meta['dial_cohort_id'] ?? ''));
        $out = ['tenant' => $meta];
        if ($cohortId !== '' && (! isset($body['materialise']) || ! empty($body['materialise']))) {
            $out['job'] = $dialRunner->syncNow(
                $cohortId,
                ['reason' => 'routing_prefix_change'],
                is_string($actor) ? $actor : null
            );
        }
        JsonResponse::send(200, $out);
    }

    // S10.5 — catalog DID ownership (HoR). List = read; assign/release = fleet_edge.
    if ($method === 'GET' && $path === '/api/v1/dids') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, (new DidInventory($registrar))->listAll());
    }

    if ($method === 'GET' && $path === '/api/v1/dids/reconcile') {
        Auth::requireAbility(FleetAbilities::EDGE);
        JsonResponse::send(200, (new DidInventory($registrar))->reconcile(new SbcFleetClient()));
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

    // C3 — provision MAC index (routing HoR) + map project
    if ($method === 'GET' && $path === '/api/v1/mac-index') {
        Auth::requireAbility(FleetAbilities::READ);
        JsonResponse::send(200, (new MacIndexStore($registrar))->getIndex());
    }

    if ($method === 'POST' && $path === '/api/v1/mac-index/claim') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new MacIndexStore($registrar))->claim(is_array($body) ? $body : []));
    }

    if ($method === 'POST' && $path === '/api/v1/mac-index/clear') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new MacIndexStore($registrar))->clear(is_array($body) ? $body : []));
    }

    if ($method === 'POST' && $path === '/api/v1/mac-index/project') {
        Auth::requireAbility(FleetAbilities::EDGE);
        JsonResponse::send(200, (new MacIndexStore($registrar))->projectMap());
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

    if ($method === 'POST' && $path === '/api/v1/reconcile/prune-orphans') {
        Auth::requireAbility(FleetAbilities::EDGE);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, (new CatalogReconcile($registrar, new SbcFleetClient()))->pruneOrphans(
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
        $result = $registrar->patchInstance(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        );
        if (isset($body['status']) && (string) $body['status'] === 'decommissioned') {
            $result = InstanceEdgeLifecycle::attachFail2banRetire($result, new SbcFleetClient(), $m[1]);
        }
        JsonResponse::send(200, $result);
    }

    if ($method === 'POST' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)/decommission$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        $result = $registrar->decommissionInstance(
            $m[1],
            $body,
            is_string($actor) ? $actor : null
        );
        $result = InstanceEdgeLifecycle::attachFail2banRetire($result, new SbcFleetClient(), $m[1]);
        JsonResponse::send(200, $result);
    }

    if ($method === 'POST' && preg_match('#^/api/v1/instances/([A-Za-z0-9_-]+)/remove$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $registrar->removeInstanceFromCatalog(
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

    if ($method === 'POST' && $path === '/api/v1/tenants/provision') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $result = (new TenantProvisioner($registrar, new SbcFleetClient()))->provision($body);
        $ok = ! empty($result['ok']);
        $status = $ok ? 201 : 502;
        JsonResponse::send($status, $result);
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

    if ($method === 'POST' && preg_match('#^/api/v1/tenants/([a-z0-9]+)/decommission$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $registrar->decommissionTenant(
            $m[1],
            is_array($body) ? $body : [],
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && $path === '/api/v1/s3/presign') {
        Auth::requireAbility(FleetAbilities::MOVES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        JsonResponse::send(200, $presign->create($body));
    }

    // Node/SBC → Gatekeeper ops events (misconfig REGISTER, Fail2ban ban). Break-glass / fleet_admin.
    if ($method === 'POST' && $path === '/api/v1/ops-events') {
        Auth::requireAbility(FleetAbilities::ADMIN);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $type = is_string($body['type'] ?? null) ? $body['type'] : '';
        $cooldown = (int) (getenv('GATEKEEPER_OPS_EVENT_COOLDOWN') ?: OpsEventThrottle::DEFAULT_COOLDOWN_SECONDS);
        $cooldown = $cooldown > 0 ? $cooldown : OpsEventThrottle::DEFAULT_COOLDOWN_SECONDS;

        if ($type === 'misconfig_register') {
            $instanceId = trim((string) ($body['instance_id'] ?? ''));
            $extension = trim((string) ($body['extension'] ?? ''));
            $endpointUid = is_string($body['endpoint_uid'] ?? null) ? trim($body['endpoint_uid']) : '';
            $sourceIp = trim((string) ($body['source_ip'] ?? ''));
            if ($instanceId === '' || $sourceIp === '') {
                throw new \InvalidArgumentException('instance_id and source_ip required', 422);
            }
            $count = (int) ($body['count'] ?? 0);
            if ($count < 1) {
                throw new \InvalidArgumentException('count must be >= 1', 422);
            }
            $throttleId = $endpointUid !== '' ? $endpointUid : ($extension !== '' ? $extension : 'unknown');
            $key = 'misconfig_register:'.$instanceId.':'.$throttleId.':'.$sourceIp;
            if (! OpsEventThrottle::allow($key, $cooldown)) {
                JsonResponse::send(200, ['accepted' => true, 'notified' => false, 'reason' => 'throttled']);
            }
            NotifyDispatcher::fromEnv()->notifyMisconfigRegister([
                'instance_id' => $instanceId,
                'instance_label' => is_string($body['instance_label'] ?? null) ? $body['instance_label'] : '',
                'fqdn' => is_string($body['fqdn'] ?? null) ? $body['fqdn'] : '',
                'extension' => $extension !== '' ? $extension : '(unknown)',
                'endpoint_uid' => $endpointUid,
                'endpoint_name' => is_string($body['endpoint_name'] ?? null) ? trim($body['endpoint_name']) : '',
                'source_ip' => $sourceIp,
                'count' => $count,
                'window_seconds' => (int) ($body['window_seconds'] ?? 600),
                'sample' => is_string($body['sample'] ?? null) ? $body['sample'] : '',
            ]);
            JsonResponse::send(200, ['accepted' => true, 'notified' => true]);
        }

        if ($type === 'fail2ban_ban') {
            $sourceIp = trim((string) ($body['source_ip'] ?? ''));
            if ($sourceIp === '' || filter_var($sourceIp, FILTER_VALIDATE_IP) === false) {
                throw new \InvalidArgumentException('source_ip must be a valid IP', 422);
            }
            $jail = trim((string) ($body['jail'] ?? 'opensips-brute-force'));
            if ($jail === '') {
                $jail = 'opensips-brute-force';
            }
            $key = 'fail2ban_ban:'.$jail.':'.$sourceIp;
            if (! OpsEventThrottle::allow($key, $cooldown)) {
                JsonResponse::send(200, ['accepted' => true, 'notified' => false, 'reason' => 'throttled']);
            }
            NotifyDispatcher::fromEnv()->notifyFail2banBan([
                'source_ip' => $sourceIp,
                'jail' => $jail,
                'sbc_fqdn' => is_string($body['sbc_fqdn'] ?? null) ? trim($body['sbc_fqdn']) : '',
                'currently_banned' => (int) ($body['currently_banned'] ?? 0),
            ]);
            JsonResponse::send(200, ['accepted' => true, 'notified' => true]);
        }

        if ($type === 'egress_unavail') {
            $instanceId = trim((string) ($body['instance_id'] ?? ''));
            if ($instanceId === '') {
                throw new \InvalidArgumentException('instance_id required', 422);
            }
            $transition = trim((string) ($body['transition'] ?? ''));
            if ($transition !== 'down' && $transition !== 'cleared') {
                throw new \InvalidArgumentException('transition must be down or cleared', 422);
            }
            // Throttle down only (cleared always allowed so recovery mail is not swallowed).
            if ($transition === 'down') {
                $key = 'egress_unavail:'.$instanceId.':down';
                if (! OpsEventThrottle::allow($key, $cooldown)) {
                    JsonResponse::send(200, ['accepted' => true, 'notified' => false, 'reason' => 'throttled']);
                }
            }
            NotifyDispatcher::fromEnv()->notifyEgressQualify([
                'instance_id' => $instanceId,
                'instance_label' => is_string($body['instance_label'] ?? null) ? $body['instance_label'] : '',
                'fqdn' => is_string($body['fqdn'] ?? null) ? $body['fqdn'] : '',
                'state' => is_string($body['state'] ?? null) ? $body['state'] : '',
                'rtt_ms' => $body['rtt_ms'] ?? null,
                'consecutive_unavail' => (int) ($body['consecutive_unavail'] ?? 0),
                'egress_trunk' => is_string($body['egress_trunk'] ?? null) ? $body['egress_trunk'] : 'Egress',
                'latency' => is_string($body['latency'] ?? null) ? $body['latency'] : '',
            ], $transition);
            JsonResponse::send(200, ['accepted' => true, 'notified' => true]);
        }

        if ($type === 'velocity_irsf') {
            $instanceId = trim((string) ($body['instance_id'] ?? ''));
            if ($instanceId === '') {
                throw new \InvalidArgumentException('instance_id required', 422);
            }
            $transition = trim((string) ($body['transition'] ?? ''));
            if ($transition !== 'down' && $transition !== 'cleared') {
                throw new \InvalidArgumentException('transition must be down or cleared', 422);
            }
            $extension = trim((string) ($body['extension'] ?? ''));
            if ($extension === '') {
                $extension = '(unknown)';
            }
            $count = (int) ($body['count'] ?? 0);
            if ($transition === 'down' && $count < 1) {
                throw new \InvalidArgumentException('count must be >= 1 for down', 422);
            }
            // Throttle down per instance+extension; cleared always allowed.
            if ($transition === 'down') {
                $key = 'velocity_irsf:'.$instanceId.':'.$extension;
                if (! OpsEventThrottle::allow($key, $cooldown)) {
                    JsonResponse::send(200, ['accepted' => true, 'notified' => false, 'reason' => 'throttled']);
                }
            }
            $masked = $body['masked_prefixes'] ?? [];
            if (! is_array($masked)) {
                $masked = [];
            }
            $masked = array_values(array_filter(array_map(
                static fn ($v) => is_string($v) ? trim($v) : '',
                $masked
            ), static fn ($v) => $v !== ''));

            NotifyDispatcher::fromEnv()->notifyVelocityIrsf([
                'instance_id' => $instanceId,
                'instance_label' => is_string($body['instance_label'] ?? null) ? $body['instance_label'] : '',
                'fqdn' => is_string($body['fqdn'] ?? null) ? $body['fqdn'] : '',
                'extension' => $extension,
                'accountcode' => is_string($body['accountcode'] ?? null) ? trim($body['accountcode']) : '',
                'count' => $count,
                'window_minutes' => (int) ($body['window_minutes'] ?? 5),
                'masked_prefixes' => $masked,
                'first_calldate' => is_string($body['first_calldate'] ?? null) ? $body['first_calldate'] : '',
                'last_calldate' => is_string($body['last_calldate'] ?? null) ? $body['last_calldate'] : '',
                'rule' => is_string($body['rule'] ?? null) ? $body['rule'] : 'irsf',
                'auto_block' => ! empty($body['auto_block']),
                'forwards_cleared' => ! empty($body['forwards_cleared']),
                'hung_up_count' => (int) ($body['hung_up_count'] ?? 0),
                'act_skipped_reason' => is_string($body['act_skipped_reason'] ?? null) ? trim($body['act_skipped_reason']) : '',
                'attribution_reason' => is_string($body['attribution_reason'] ?? null) ? trim($body['attribution_reason']) : '',
                'extension_shortuid' => is_string($body['extension_shortuid'] ?? null) ? trim($body['extension_shortuid']) : '',
            ], $transition);
            JsonResponse::send(200, ['accepted' => true, 'notified' => true]);
        }

        if ($type === 'velocity_off_hours') {
            $instanceId = trim((string) ($body['instance_id'] ?? ''));
            if ($instanceId === '') {
                throw new \InvalidArgumentException('instance_id required', 422);
            }
            $transition = trim((string) ($body['transition'] ?? ''));
            if ($transition !== 'down' && $transition !== 'cleared') {
                throw new \InvalidArgumentException('transition must be down or cleared', 422);
            }
            $extension = trim((string) ($body['extension'] ?? ''));
            if ($extension === '') {
                $extension = '(unknown)';
            }
            $count = (int) ($body['count'] ?? 0);
            if ($transition === 'down' && $count < 1) {
                throw new \InvalidArgumentException('count must be >= 1 for down', 422);
            }
            if ($transition === 'down') {
                $key = 'velocity_off_hours:'.$instanceId.':'.$extension;
                if (! OpsEventThrottle::allow($key, $cooldown)) {
                    JsonResponse::send(200, ['accepted' => true, 'notified' => false, 'reason' => 'throttled']);
                }
            }
            $masked = $body['masked_prefixes'] ?? [];
            if (! is_array($masked)) {
                $masked = [];
            }
            $masked = array_values(array_filter(array_map(
                static fn ($v) => is_string($v) ? trim($v) : '',
                $masked
            ), static fn ($v) => $v !== ''));

            NotifyDispatcher::fromEnv()->notifyVelocityOffHours([
                'instance_id' => $instanceId,
                'instance_label' => is_string($body['instance_label'] ?? null) ? $body['instance_label'] : '',
                'fqdn' => is_string($body['fqdn'] ?? null) ? $body['fqdn'] : '',
                'extension' => $extension,
                'accountcode' => is_string($body['accountcode'] ?? null) ? trim($body['accountcode']) : '',
                'count' => $count,
                'window_minutes' => (int) ($body['window_minutes'] ?? 60),
                'masked_prefixes' => $masked,
                'first_calldate' => is_string($body['first_calldate'] ?? null) ? $body['first_calldate'] : '',
                'last_calldate' => is_string($body['last_calldate'] ?? null) ? $body['last_calldate'] : '',
                'rule' => is_string($body['rule'] ?? null) ? $body['rule'] : 'off_hours',
                'auto_block' => ! empty($body['auto_block']),
                'forwards_cleared' => ! empty($body['forwards_cleared']),
                'hung_up_count' => (int) ($body['hung_up_count'] ?? 0),
                'act_skipped_reason' => is_string($body['act_skipped_reason'] ?? null) ? trim($body['act_skipped_reason']) : '',
                'attribution_reason' => is_string($body['attribution_reason'] ?? null) ? trim($body['attribution_reason']) : '',
                'extension_shortuid' => is_string($body['extension_shortuid'] ?? null) ? trim($body['extension_shortuid']) : '',
            ], $transition);
            JsonResponse::send(200, ['accepted' => true, 'notified' => true]);
        }

        throw new \InvalidArgumentException(
            'Unsupported ops-event type (expected misconfig_register, fail2ban_ban, egress_unavail, velocity_irsf, or velocity_off_hours)',
            422
        );
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

    // Fleet Delete (Rule 14) — durable job
    if ($method === 'POST' && $path === '/api/v1/tenant-deletes') {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $actor = Auth::user()['email'] ?? null;
        if (is_string($actor) && $actor !== '' && empty($body['created_by'])) {
            $body['created_by'] = $actor;
        }
        $job = $deleteJobs->create($body, $registrar);
        JsonResponse::send(201, $deleteRunner->runUntilGate(
            (string) $job['job_id'],
            (string) $job['tenant_shortuid']
        ));
    }

    if ($method === 'GET' && $path === '/api/v1/tenant-deletes') {
        Auth::requireAbility(FleetAbilities::READ);
        $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 50;
        JsonResponse::send(200, ['jobs' => $deleteJobs->list($limit)]);
    }

    if ($method === 'GET' && preg_match('#^/api/v1/tenant-deletes/([A-Za-z0-9_-]+)$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::READ);
        $shortuid = $_GET['tenant'] ?? null;
        JsonResponse::send(200, $deleteJobs->get($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-deletes/([A-Za-z0-9_-]+)/run$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? ($_GET['tenant'] ?? null);
        JsonResponse::send(200, $deleteRunner->runUntilGate($m[1], is_string($shortuid) ? $shortuid : null));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-deletes/([A-Za-z0-9_-]+)/confirm$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        if (! is_array($body)) {
            $body = [];
        }
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $deleteRunner->confirm(
            $m[1],
            $body,
            is_string($shortuid) ? $shortuid : null,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-deletes/([A-Za-z0-9_-]+)/abort$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $deleteRunner->abort(
            $m[1],
            is_string($shortuid) ? $shortuid : null,
            is_string($actor) ? $actor : null
        ));
    }

    if ($method === 'POST' && preg_match('#^/api/v1/tenant-deletes/([A-Za-z0-9_-]+)/retry$#', $path, $m)) {
        Auth::requireAbility(FleetAbilities::INSTANCES);
        $body = json_decode((string) file_get_contents('php://input'), true) ?: [];
        $shortuid = $body['tenant_shortuid'] ?? null;
        $actor = Auth::user()['email'] ?? null;
        JsonResponse::send(200, $deleteRunner->retry(
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
    $payload = ['error' => $e->getMessage()];
    if ($e instanceof CatalogIntegrityException) {
        $payload['blocking_tenants'] = $e->blockingTenants;
    }
    JsonResponse::send($code, $payload);
}
