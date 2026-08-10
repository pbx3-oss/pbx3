<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Advance a tenant-delete job until awaiting_confirm or terminal.
 *
 * Human gate: awaiting_confirm (typed shortuid + confirm).
 * Then: removing_edge → wiping_node → catalog → completed.
 */
final class TenantDeleteRunner
{
    private Client $http;

    private string $fleetToken;

    public function __construct(
        private readonly TenantDeleteJobStore $jobs,
        private readonly S3Registrar $registrar,
        private readonly SbcFleetClient $sbc,
        private readonly ?DialCohortStore $dialCohorts = null,
        private readonly ?DialCohortMaterialiseRunner $dialRunner = null,
    ) {
        $this->fleetToken = getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '';
        $this->http = new Client([
            'timeout' => 300,
            'http_errors' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    public function runUntilGate(string $jobId, ?string $shortuid = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $guard = 0;
        while ($guard++ < 20) {
            $state = (string) ($job['state'] ?? '');
            if (in_array($state, ['awaiting_confirm', 'completed', 'failed', 'aborted'], true)) {
                return $job;
            }
            $job = $this->step($job);
            if (($job['state'] ?? '') === 'failed') {
                return $job;
            }
        }

        return $job;
    }

    /**
     * Confirm human gate then run destructive phases to completion.
     *
     * @param  array<string, mixed>  $body  typed_shortuid + confirm true
     * @return array<string, mixed>
     */
    public function confirm(string $jobId, array $body, ?string $shortuid = null, ?string $actor = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $state = (string) ($job['state'] ?? '');
        if ($state !== 'awaiting_confirm') {
            throw new \InvalidArgumentException("Job not in awaiting_confirm (state={$state})", 409);
        }
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required', 422);
        }
        $typed = strtolower(trim((string) ($body['typed_shortuid'] ?? $body['shortuid'] ?? '')));
        $expect = strtolower((string) ($job['tenant_shortuid'] ?? ''));
        if ($typed === '' || $typed !== $expect) {
            throw new \InvalidArgumentException('typed_shortuid must match tenant_shortuid exactly', 422);
        }

        $job = $this->stampActor($job, $actor);
        $job = $this->markPhase($job, 'awaiting_confirm', 'ok', 'operator confirmed');
        $job = $this->setState($job, 'pruning_mesh');
        $job['rollback']['safe_to_abort'] = true;
        $job['rollback']['hint'] = 'Mesh prune / edge domain may already be in progress — Register on SBC can repair until wipe.';
        $this->jobs->writePublic($job);

        return $this->runDestructive($job);
    }

    /**
     * @return array<string, mixed>
     */
    public function abort(string $jobId, ?string $shortuid = null, ?string $actor = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $state = (string) ($job['state'] ?? '');
        if (in_array($state, ['completed', 'aborted'], true)) {
            throw new \InvalidArgumentException("Job already terminal (state={$state})", 409);
        }
        $wipeOk = (($job['phases']['wiping_node']['status'] ?? '') === 'ok');
        if ($wipeOk || ! ($job['rollback']['safe_to_abort'] ?? true)) {
            throw new \InvalidArgumentException('Job is not safe to abort after node wipe started', 409);
        }

        $job['state'] = 'aborted';
        $job['error'] = null;
        $job['next_human_action'] = null;
        $job['completed_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job['rollback']['safe_to_abort'] = false;
        $job['rollback']['hint'] = 'Aborted before node wipe — catalog tenant still active; re-register SBC domain if removed.';
        $job = $this->stampActor($job, $actor);
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);
        $this->notifyTerminal($job, 'aborted');

        return $job;
    }

    /**
     * @return array<string, mixed>
     */
    public function retry(string $jobId, ?string $shortuid = null, ?string $actor = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        if (($job['state'] ?? '') !== 'failed') {
            throw new \InvalidArgumentException('Retry only allowed when state=failed', 409);
        }

        $resume = self::failedPhaseName($job) ?? 'pending';
        $phases = is_array($job['phases'] ?? null) ? $job['phases'] : [];
        if (isset($phases[$resume])) {
            $phases[$resume]['status'] = 'pending';
            unset($phases[$resume]['finished_at'], $phases[$resume]['message']);
            $job['phases'] = $phases;
        }

        $job['state'] = $resume === 'pending' ? 'pending' : $resume;
        $job['error'] = null;
        $job['completed_at'] = null;
        $job['rollback']['safe_to_abort'] = ! in_array($resume, ['wiping_node', 'catalog'], true);
        $job = $this->stampActor($job, $actor);
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);

        if (in_array($job['state'], ['pruning_mesh', 'removing_edge', 'wiping_node', 'catalog'], true)) {
            return $this->runDestructive($job);
        }

        return $this->runUntilGate($jobId, (string) ($job['tenant_shortuid'] ?? $shortuid));
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function step(array $job): array
    {
        $state = (string) ($job['state'] ?? '');
        try {
            return match ($state) {
                'pending' => $this->enter($job, 'preflight'),
                'preflight' => $this->after(
                    $job,
                    'preflight',
                    fn () => $this->phasePreflight($job),
                    'awaiting_confirm',
                    'Type the tenant shortuid and confirm irreversible delete (SBC domain + node wipe + catalog soft-decom).'
                ),
                default => throw new \RuntimeException("Cannot auto-advance from state {$state}", 409),
            };
        } catch (\Throwable $e) {
            return $this->fail($job, $state === 'pending' ? 'preflight' : $state, $e);
        }
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function runDestructive(array $job): array
    {
        $guard = 0;
        while ($guard++ < 20) {
            $state = (string) ($job['state'] ?? '');
            if (in_array($state, ['completed', 'failed', 'aborted'], true)) {
                return $job;
            }
            try {
                $job = match ($state) {
                    'pruning_mesh' => $this->after(
                        $job,
                        'pruning_mesh',
                        fn () => $this->phasePruningMesh($job),
                        'removing_edge'
                    ),
                    'removing_edge' => $this->after(
                        $job,
                        'removing_edge',
                        fn () => $this->phaseRemovingEdge($job),
                        'wiping_node'
                    ),
                    'wiping_node' => $this->after(
                        $job,
                        'wiping_node',
                        fn () => $this->phaseWipingNode($job),
                        'catalog'
                    ),
                    'catalog' => $this->finishCatalog($job),
                    default => throw new \RuntimeException("Unexpected destructive state {$state}", 409),
                };
            } catch (\Throwable $e) {
                return $this->fail($job, $state, $e);
            }
            if (($job['state'] ?? '') === 'wiping_node' || (($job['phases']['wiping_node']['status'] ?? '') === 'running')) {
                $job['rollback']['safe_to_abort'] = false;
            }
        }

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phasePreflight(array $job): array
    {
        $shortuid = (string) $job['tenant_shortuid'];
        $meta = $this->registrar->getTenant($shortuid);
        $api = (string) ($job['api_base_url'] ?? '');
        if ($api === '') {
            throw new \RuntimeException('api_base_url missing — cannot wipe node', 422);
        }
        $fqdn = (string) ($job['tenant_fqdn'] ?? $meta['fqdn'] ?? '');
        if ($fqdn === '') {
            throw new \RuntimeException('tenant_fqdn missing — cannot delete SBC domain', 422);
        }
        $job['tenant_fqdn'] = $fqdn;
        $job['tenant_pkey'] = $meta['cname'] ?? $meta['pkey'] ?? $job['tenant_pkey'] ?? null;

        $warnings = [];
        try {
            $dids = $this->registrar->getDidInventory($shortuid);
            $rows = is_array($dids['dids'] ?? null) ? $dids['dids'] : (is_array($dids) ? $dids : []);
            $active = 0;
            foreach ($rows as $row) {
                if (! is_array($row)) {
                    continue;
                }
                $st = strtolower((string) ($row['status'] ?? 'active'));
                if (in_array($st, DidInventory::OWNING_STATUSES, true)) {
                    $active++;
                }
            }
            if ($active > 0) {
                $warnings[] = "Catalog still has {$active} DID(s) attached — unassign separately (not auto-cleared in v1).";
            }
        } catch (\Throwable) {
            // no dids.json is fine
        }

        // Soft reachability check
        try {
            $this->nodeGet(rtrim($api, '/'), '/fleet/preflight');
        } catch (\Throwable $e) {
            $warnings[] = 'Node preflight check failed: '.$e->getMessage();
        }

        // T1 — node wipe blast-radius counts (informational; never blocks confirm).
        try {
            $wipe = $this->nodeGet(
                rtrim($api, '/'),
                '/fleet/tenants/'.rawurlencode($shortuid).'/wipe-preflight'
            );
            $job['wipe_counts'] = is_array($wipe['wipe'] ?? null) ? $wipe['wipe'] : $wipe;
            $total = (int) ($job['wipe_counts']['total_rows'] ?? 0);
            $phaseMsg = "node wipe would remove {$total} child row(s) + cluster";
        } catch (\Throwable $e) {
            $job['wipe_counts'] = null;
            $warnings[] = 'Node wipe-preflight failed: '.$e->getMessage();
            $phaseMsg = 'wipe counts unavailable';
        }

        $job['warnings'] = $warnings;
        $job = $this->markPhase($job, 'preflight', 'ok', $phaseMsg);
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * T2 / I7 — detach from Site Group + prune peer dialaliases on reachable homes.
     *
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phasePruningMesh(array $job): array
    {
        $shortuid = strtolower(trim((string) ($job['tenant_shortuid'] ?? '')));
        $fqdn = strtolower(trim((string) ($job['tenant_fqdn'] ?? '')));
        $warnings = is_array($job['warnings'] ?? null) ? $job['warnings'] : [];
        $actor = is_string($job['last_action_by'] ?? null) ? $job['last_action_by'] : null;

        if ($this->dialCohorts === null || $this->dialRunner === null) {
            $job = $this->markPhase($job, 'pruning_mesh', 'skipped', 'dial cohort services not wired');
            $this->jobs->writePublic($job);

            return $job;
        }

        $meta = [];
        try {
            $meta = $this->registrar->getTenantMeta($shortuid);
        } catch (\Throwable) {
            // fall through
        }
        if ($meta === []) {
            try {
                $meta = $this->registrar->getTenant($shortuid);
            } catch (\Throwable) {
                $meta = [];
            }
        }
        if ($fqdn === '') {
            $fqdn = strtolower(trim((string) ($meta['fqdn'] ?? '')));
        }
        $cohortId = trim((string) ($meta['dial_cohort_id'] ?? ''));

        if ($cohortId === '') {
            $job = $this->markPhase($job, 'pruning_mesh', 'ok', 'no Site Group membership — same-home prune via node wipe only');
            $this->jobs->writePublic($job);

            return $job;
        }

        $remaining = [];
        try {
            $removed = $this->dialCohorts->removeMember($cohortId, $shortuid, $actor);
            $remaining = DialCohortStore::normalizeMembers($removed['cohort']['members'] ?? []);
        } catch (\Throwable $e) {
            $code = (int) $e->getCode();
            // Already removed from cohort (retry) — continue prune against current members.
            if ($code === 404) {
                try {
                    $doc = $this->dialCohorts->get($cohortId);
                    $remaining = DialCohortStore::normalizeMembers($doc['members'] ?? []);
                    $remaining = array_values(array_filter(
                        $remaining,
                        static fn (string $s): bool => $s !== $shortuid
                    ));
                } catch (\Throwable $e2) {
                    $warnings[] = 'Site Group detach skipped: '.$e->getMessage().'; then '.$e2->getMessage();
                    $job['warnings'] = $warnings;
                    $job = $this->markPhase($job, 'pruning_mesh', 'ok', 'detach skipped; see warnings');
                    $this->jobs->writePublic($job);

                    return $job;
                }
            } else {
                $warnings[] = 'Site Group detach failed: '.$e->getMessage()
                    .' — fix catalog membership then Sync now / retry.';
                $job['warnings'] = $warnings;
                $job = $this->markPhase($job, 'pruning_mesh', 'ok', 'detach failed; see warnings');
                $this->jobs->writePublic($job);

                return $job;
            }
        }

        $prune = $this->dialRunner->pruneInboundTargetingTenant($shortuid, $fqdn, $remaining);
        foreach ($prune['warnings'] ?? [] as $w) {
            if (is_string($w) && $w !== '') {
                $warnings[] = $w;
            }
        }
        $deleted = (int) ($prune['deletes'] ?? 0);
        $homes = count($prune['homes_ok'] ?? []);
        $msg = "Site Group {$cohortId}: pruned {$deleted} peer dialalias row(s) on {$homes} home(s)";
        if ($warnings !== []) {
            $msg .= '; '.count($warnings).' warning(s) — operator: retry / Sync now';
        }

        $job['warnings'] = $warnings;
        $job['mesh_prune'] = [
            'cohort_id' => $cohortId,
            'deletes' => $deleted,
            'homes_ok' => $prune['homes_ok'] ?? [],
        ];
        $job = $this->markPhase($job, 'pruning_mesh', 'ok', $msg);
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseRemovingEdge(array $job): array
    {
        $fqdn = (string) ($job['tenant_fqdn'] ?? '');
        $this->sbc->deleteDomain($fqdn);
        $job['rollback']['safe_to_abort'] = true;
        $job['rollback']['hint'] = 'SBC domain removed — Register on SBC can restore until wipe.';
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseWipingNode(array $job): array
    {
        $shortuid = (string) $job['tenant_shortuid'];
        $api = rtrim((string) $job['api_base_url'], '/');
        $job['rollback']['safe_to_abort'] = false;
        $job['rollback']['hint'] = 'Node wipe in progress or done — abort not available.';
        $this->jobs->writePublic($job);

        try {
            $this->nodeDelete($api, '/fleet/tenants/'.rawurlencode($shortuid));
        } catch (\RuntimeException $e) {
            if ($e->getCode() !== 404) {
                throw $e;
            }
        }

        $certNote = 'cert sync skipped';
        $email = getenv('PBX3_LE_EMAIL') ?: '';
        if ($email !== '') {
            try {
                $this->nodePost($api, '/fleet/certificates/sync', ['email' => $email]);
                $certNote = 'cert sync ok';
            } catch (\Throwable $e) {
                $certNote = 'LE sync skipped ('.$e->getMessage().')';
            }
        }
        try {
            $this->nodePost($api, '/fleet/commit', []);
        } catch (\Throwable $e) {
            // commit after wipe is best-effort
            $certNote .= '; commit: '.$e->getMessage();
        }

        $job = $this->markPhase($job, 'wiping_node', 'ok', 'node wiped; '.$certNote);
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function finishCatalog(array $job): array
    {
        $job = $this->markPhase($job, 'catalog', 'running');
        $this->jobs->writePublic($job);
        $this->registrar->decommissionTenant(
            (string) $job['tenant_shortuid'],
            ['confirm' => true, 'notes' => 'Fleet Delete job '.(string) $job['job_id']],
            is_string($job['last_action_by'] ?? null) ? $job['last_action_by'] : null
        );
        $job = $this->markPhase($job, 'catalog', 'ok');
        $job['state'] = 'completed';
        $job['completed_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job['next_human_action'] = null;
        $job['error'] = null;
        $job['rollback']['safe_to_abort'] = false;
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function enter(array $job, string $state): array
    {
        return $this->setState($job, $state);
    }

    /**
     * @param  array<string, mixed>  $job
     * @param  callable(): array<string, mixed>  $fn
     * @return array<string, mixed>
     */
    private function after(array $job, string $phase, callable $fn, string $next, ?string $human = null): array
    {
        $job = $this->markPhase($job, $phase, 'running');
        $this->jobs->writePublic($job);
        $job = $fn();
        if (($job['phases'][$phase]['status'] ?? '') !== 'ok') {
            $job = $this->markPhase($job, $phase, 'ok');
        }
        $job = $this->setState($job, $next, $human);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function fail(array $job, string $phase, \Throwable $e): array
    {
        $job['state'] = 'failed';
        $job['error'] = $e->getMessage();
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job = $this->markPhase($job, $phase, 'failed', $e->getMessage());
        $this->jobs->writePublic($job);
        $this->notifyTerminal($job, 'failed');

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function setState(array $job, string $state, ?string $human = null): array
    {
        $job['state'] = $state;
        $job['next_human_action'] = $human;
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job['error'] = null;
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function markPhase(array $job, string $phase, string $status, ?string $message = null): array
    {
        $phases = is_array($job['phases'] ?? null) ? $job['phases'] : [];
        $row = is_array($phases[$phase] ?? null) ? $phases[$phase] : [];
        if ($status === 'running') {
            $row['started_at'] = $row['started_at'] ?? gmdate('Y-m-d\TH:i:s\Z');
        }
        if (in_array($status, ['ok', 'failed', 'skipped'], true)) {
            $row['finished_at'] = gmdate('Y-m-d\TH:i:s\Z');
        }
        $row['status'] = $status;
        if ($message !== null) {
            $row['message'] = $message;
        }
        $phases[$phase] = $row;
        $job['phases'] = $phases;

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function stampActor(array $job, ?string $actor): array
    {
        if ($actor !== null && $actor !== '') {
            $job['last_action_by'] = $actor;
        }

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     */
    private static function failedPhaseName(array $job): ?string
    {
        $phases = is_array($job['phases'] ?? null) ? $job['phases'] : [];
        foreach (array_reverse(array_keys($phases)) as $name) {
            if (($phases[$name]['status'] ?? '') === 'failed') {
                return (string) $name;
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $job
     * @param  'failed'|'aborted'  $outcome
     */
    private function notifyTerminal(array $job, string $outcome): void
    {
        try {
            // Reuse move-job notify shape (same fields operators care about).
            NotifyDispatcher::fromEnv()->notifyMoveJobTerminal($job, $outcome);
        } catch (\Throwable $e) {
            error_log('[gatekeeper-notify] delete job '.$outcome.' mail failed: '.$e->getMessage());
        }
    }

    private function requireFleetToken(): void
    {
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }
    }

    /** @return array<string, mixed> */
    private function nodeGet(string $apiBase, string $path): array
    {
        return $this->requestJson('GET', rtrim($apiBase, '/').$path);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function nodePost(string $apiBase, string $path, array $body): array
    {
        return $this->requestJson('POST', rtrim($apiBase, '/').$path, $body);
    }

    /** @return array<string, mixed> */
    private function nodeDelete(string $apiBase, string $path): array
    {
        return $this->requestJson('DELETE', rtrim($apiBase, '/').$path);
    }

    /**
     * @param  array<string, mixed>|null  $body
     * @return array<string, mixed>
     */
    private function requestJson(string $method, string $url, ?array $body = null): array
    {
        $this->requireFleetToken();
        $opts = [
            'headers' => [
                'Authorization' => 'Bearer '.$this->fleetToken,
                'Accept' => 'application/json',
            ],
        ];
        if ($body !== null) {
            $opts['headers']['Content-Type'] = 'application/json';
            $opts['json'] = $body;
        }

        try {
            $res = $this->http->request($method, $url, $opts);
        } catch (GuzzleException $e) {
            throw new \RuntimeException("HTTP {$method} {$url}: ".$e->getMessage(), 502);
        }

        $code = $res->getStatusCode();
        $decoded = json_decode((string) $res->getBody(), true);
        if ($code >= 400) {
            $msg = is_array($decoded)
                ? ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded))
                : (string) $res->getBody();
            throw new \RuntimeException(
                "HTTP {$method} {$url} → {$code}: {$msg}",
                $code >= 400 && $code < 600 ? $code : 502
            );
        }

        return is_array($decoded) ? $decoded : [];
    }
}
