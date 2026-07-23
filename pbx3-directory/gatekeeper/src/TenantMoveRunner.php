<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Advance a tenant-move job through automated phases until a human gate or failure.
 *
 * Human gates: verifying (operator confirms test call), awaiting_cleanup (full source wipe + cert sync + commit).
 */
final class TenantMoveRunner
{
    private Client $http;

    private string $fleetToken;

    private string $sbcApiBase;

    public function __construct(
        private readonly TenantMoveJobStore $jobs,
        private readonly S3Presign $presign,
        private readonly S3Registrar $registrar,
    ) {
        $this->fleetToken = getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '';
        $this->sbcApiBase = ControlSettingsStore::sbcAdminApiUrl();
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
            if (in_array($state, ['verifying', 'awaiting_cleanup', 'completed', 'failed', 'aborted'], true)) {
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
     * Confirm a human gate and continue.
     *
     * @return array<string, mixed>
     */
    public function confirm(string $jobId, string $gate, ?string $shortuid = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $state = (string) ($job['state'] ?? '');

        if ($gate === 'verifying') {
            if ($state !== 'verifying') {
                throw new \InvalidArgumentException("Job not in verifying (state={$state})", 409);
            }
            $job = $this->markPhase($job, 'verifying', 'ok', 'operator confirmed');
            $job = $this->setState($job, 'catalog');
            $job = $this->phaseCatalog($job);
            $job = $this->setState($job, 'awaiting_cleanup', 'Confirm full wipe of tenant on source (all cluster data + portable users; then cert sync + commit). Irreversible.');

            return $job;
        }

        if ($gate === 'cleanup') {
            if ($state !== 'awaiting_cleanup') {
                throw new \InvalidArgumentException("Job not in awaiting_cleanup (state={$state})", 409);
            }
            try {
                $job = $this->phaseCleanup($job);
            } catch (\Throwable $e) {
                $job['state'] = 'awaiting_cleanup';
                $job['error'] = $e->getMessage();
                $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
                $job['next_human_action'] = 'Retry source wipe (full delete + cert sync + commit).';
                $job = $this->markPhase($job, 'awaiting_cleanup', 'failed', $e->getMessage());
                $this->jobs->writePublic($job);
                throw $e;
            }
            $job = $this->setState($job, 'completed');
            $job['completed_at'] = gmdate('Y-m-d\TH:i:s\Z');
            $job['next_human_action'] = null;
            $job['rollback']['safe_to_abort'] = false;
            $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
            $this->jobs->writePublic($job);

            return $job;
        }

        throw new \InvalidArgumentException('gate must be verifying or cleanup', 422);
    }

    /**
     * Soft-abort before cutover (or when still safe_to_abort and cutover not applied).
     *
     * @return array<string, mixed>
     */
    public function abort(string $jobId, ?string $shortuid = null, ?string $actor = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $state = (string) ($job['state'] ?? '');
        if (in_array($state, ['completed', 'aborted'], true)) {
            throw new \InvalidArgumentException("Job already terminal (state={$state})", 409);
        }
        $cutoverOk = (($job['phases']['cutover']['status'] ?? '') === 'ok');
        if ($cutoverOk) {
            throw new \InvalidArgumentException(
                'Cutover already applied — use POST …/rollback instead of abort',
                409
            );
        }
        if (! ($job['rollback']['safe_to_abort'] ?? true) && $state !== 'failed') {
            throw new \InvalidArgumentException('Job is not safe to abort', 409);
        }

        $job['state'] = 'aborted';
        $job['error'] = null;
        $job['next_human_action'] = null;
        $job['completed_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job['rollback']['safe_to_abort'] = false;
        $job['rollback']['hint'] = 'Aborted before cutover — source tenant unchanged.';
        $job = $this->stampActor($job, $actor);
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);
        $this->notifyTerminal($job, 'aborted');

        return $job;
    }

    /**
     * Clear failed state and resume the failed phase, then run until next gate.
     *
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
        $job['rollback']['safe_to_abort'] = ($resume !== 'awaiting_cleanup');
        $job['rollback']['hint'] = 'Retrying after failure — abort still possible until cutover.';
        $job = $this->stampActor($job, $actor);
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);

        return $this->runUntilGate($jobId, (string) ($job['tenant_shortuid'] ?? $shortuid));
    }

    /**
     * After cutover: SBC rollback-repoint + optional catalog flip back to source. Terminal aborted.
     *
     * @return array<string, mixed>
     */
    public function rollback(string $jobId, ?string $shortuid = null, ?string $actor = null): array
    {
        $job = $this->jobs->get($jobId, $shortuid);
        $state = (string) ($job['state'] ?? '');
        if ($state === 'completed') {
            throw new \InvalidArgumentException('Source already cleaned up — automated rollback not available', 409);
        }
        if ($state === 'aborted') {
            throw new \InvalidArgumentException('Job already aborted', 409);
        }
        $cutoverOk = (($job['phases']['cutover']['status'] ?? '') === 'ok');
        if (! $cutoverOk) {
            throw new \InvalidArgumentException('No successful cutover to roll back — use abort', 409);
        }
        $prev = (int) ($job['previous_sbc_dispatcher_setid'] ?? 0);
        $domain = (string) ($job['tenant_fqdn'] ?? '');
        if ($prev < 1 || $domain === '') {
            throw new \InvalidArgumentException('previous_sbc_dispatcher_setid and tenant_fqdn required for rollback', 422);
        }

        $this->requireFleetToken();
        if ($this->sbcApiBase === '') {
            throw new \RuntimeException('SBC admin API URL not set — cannot rollback', 503);
        }
        $this->sbcPost('/fleet/rollback-repoint', [
            'tenant_domain' => $domain,
            'previous_setid' => $prev,
        ]);

        if ((($job['phases']['catalog']['status'] ?? '') === 'ok')) {
            $this->registrar->moveTenant((string) $job['tenant_shortuid'], [
                'instance_id' => (string) $job['source_instance_id'],
            ]);
            $job = $this->markPhase($job, 'catalog', 'ok', 'rolled back to source_instance_id');
        }

        $job = $this->markPhase($job, 'cutover', 'ok', 'rolled back to setid '.$prev);
        $job['state'] = 'aborted';
        $job['error'] = null;
        $job['next_human_action'] = null;
        $job['completed_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $job['rollback']['safe_to_abort'] = false;
        $job['rollback']['hint'] = 'Rolled back SBC setid'
            .(isset($job['phases']['catalog']) ? ' and catalog home' : '')
            .' — dest tenant row may still exist; clean up manually if needed.';
        $job = $this->stampActor($job, $actor);
        $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
        $this->jobs->writePublic($job);
        $this->notifyTerminal($job, 'aborted');

        return $job;
    }

    /**
     * Which phase row is failed (for retry resume). Exposed for unit tests.
     *
     * @param  array<string, mixed>  $job
     */
    public static function failedPhaseName(array $job): ?string
    {
        foreach ((array) ($job['phases'] ?? []) as $name => $row) {
            if (! is_array($row)) {
                continue;
            }
            if (($row['status'] ?? '') === 'failed') {
                return (string) $name;
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function stampActor(array $job, ?string $actor): array
    {
        if ($actor !== null && $actor !== '') {
            $job['last_action_by'] = $actor;
            if (empty($job['created_by'])) {
                $job['created_by'] = $actor;
            }
        }

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function step(array $job): array
    {
        $state = (string) ($job['state'] ?? 'pending');

        try {
            return match ($state) {
                'pending' => $this->enter($job, 'preflight'),
                'preflight' => $this->after($job, 'preflight', fn () => $this->phasePreflight($job), 'exporting'),
                'exporting' => $this->after($job, 'exporting', fn () => $this->phaseExport($job), 'transferring'),
                'transferring' => $this->after($job, 'transferring', fn () => $job, 'importing'),
                'importing' => $this->after($job, 'importing', fn () => $this->phaseImport($job), 'configuring'),
                'configuring' => $this->after($job, 'configuring', fn () => $this->phaseCommit($job), 'cutover'),
                'cutover' => $this->after($job, 'cutover', fn () => $this->phaseCutover($job), 'awaiting_certs'),
                'awaiting_certs' => $this->after($job, 'awaiting_certs', fn () => $this->phaseCerts($job), 'verifying', 'Confirm registration / test call on destination.'),
                default => throw new \RuntimeException("Cannot auto-advance from state {$state}", 409),
            };
        } catch (\Throwable $e) {
            $job['state'] = 'failed';
            $job['error'] = $e->getMessage();
            $job['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');
            $phase = $state === 'pending' ? 'preflight' : $state;
            $job = $this->markPhase($job, $phase, 'failed', $e->getMessage());
            $this->jobs->writePublic($job);
            $this->notifyTerminal($job, 'failed');

            return $job;
        }
    }

    /**
     * @param  array<string, mixed>  $job
     * @param  'failed'|'aborted'  $outcome
     */
    private function notifyTerminal(array $job, string $outcome): void
    {
        try {
            NotifyDispatcher::fromEnv()->notifyMoveJobTerminal($job, $outcome);
        } catch (\Throwable $e) {
            error_log('[gatekeeper-notify] move job '.$outcome.' mail failed: '.$e->getMessage());
        }
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
        $job = $this->markPhase($job, $phase, 'ok');
        $job = $this->setState($job, $next, $human);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function enter(array $job, string $next): array
    {
        return $this->setState($job, $next);
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phasePreflight(array $job): array
    {
        $this->requireFleetToken();
        $src = $this->nodeGet((string) $job['source_api_base_url'], '/fleet/preflight');
        $dst = $this->nodeGet((string) $job['dest_api_base_url'], '/fleet/preflight');
        if (empty($src['ok']) || empty($dst['ok'])) {
            throw new \RuntimeException('Node preflight failed: source_ok='.json_encode($src['ok'] ?? false).' dest_ok='.json_encode($dst['ok'] ?? false));
        }

        if ($this->sbcApiBase !== '' && ! empty($job['tenant_fqdn']) && ! empty($job['dest_sbc_dispatcher_setid'])) {
            $sbc = $this->sbcPost('/fleet/preflight', [
                'tenant_domain' => $job['tenant_fqdn'],
                'dest_dispatcher_setid' => (int) $job['dest_sbc_dispatcher_setid'],
            ]);
            if (empty($sbc['ok'])) {
                throw new \RuntimeException('SBC preflight failed: '.json_encode($sbc));
            }
            if (isset($sbc['current_setid'])) {
                $job['previous_sbc_dispatcher_setid'] = (int) $sbc['current_setid'];
            }
        }

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseExport(array $job): array
    {
        $shortuid = (string) $job['tenant_shortuid'];
        $jobId = (string) $job['job_id'];
        $epoch = time();
        $key = "tenants/{$shortuid}/migration/{$jobId}/pbx3tenant.{$shortuid}.{$epoch}.zip";
        $presign = $this->presign->create([
            'method' => 'PUT',
            'key' => $key,
            'expires_in' => 1800,
        ]);
        $this->nodePost((string) $job['source_api_base_url'], '/fleet/tenants/'.rawurlencode($shortuid).'/export', [
            'presigned_put_url' => $presign['url'],
            'include_recordings' => (bool) ($job['options']['include_recordings'] ?? false),
        ]);
        $job['staging']['export_zip_key'] = $key;

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseImport(array $job): array
    {
        $key = (string) ($job['staging']['export_zip_key'] ?? '');
        if ($key === '') {
            throw new \RuntimeException('export_zip_key missing — export phase incomplete');
        }
        $presign = $this->presign->create([
            'method' => 'GET',
            'key' => $key,
            'expires_in' => 1800,
        ]);
        $this->nodePost((string) $job['dest_api_base_url'], '/fleet/tenants/import', [
            'presigned_get_url' => $presign['url'],
            'replace' => (bool) ($job['options']['replace_on_dest'] ?? false),
        ]);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCommit(array $job): array
    {
        $this->nodePost((string) $job['dest_api_base_url'], '/fleet/commit', []);

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCutover(array $job): array
    {
        if ($this->sbcApiBase === '') {
            throw new \RuntimeException('SBC admin API URL not set — cannot cutover');
        }
        $domain = (string) ($job['tenant_fqdn'] ?? '');
        $destSet = (int) ($job['dest_sbc_dispatcher_setid'] ?? 0);
        if ($domain === '' || $destSet < 1) {
            throw new \RuntimeException('tenant_fqdn and dest_sbc_dispatcher_setid required for cutover');
        }
        $result = $this->sbcPost('/fleet/repoint', [
            'tenant_domain' => $domain,
            'dest_dispatcher_setid' => $destSet,
        ]);
        if (isset($result['previous_setid'])) {
            $job['previous_sbc_dispatcher_setid'] = (int) $result['previous_setid'];
        }

        return $job;
    }

    /**
     * Dest LE sync after cutover. Best-effort: certbot flakiness must not block verifying.
     * Operator can Certificates → Sync from the SPA afterward.
     *
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCerts(array $job): array
    {
        $email = getenv('PBX3_LE_EMAIL') ?: '';
        if ($email === '') {
            // Skip LE sync when no email configured — operator can sync from SPA.
            return $job;
        }
        try {
            $this->nodePost((string) $job['dest_api_base_url'], '/fleet/certificates/sync', [
                'email' => $email,
            ]);
        } catch (\Throwable $e) {
            error_log('[tenant-move] dest cert sync after cutover: '.$e->getMessage());
            // Message is preserved when after() marks the phase ok without a new message.
            $job = $this->markPhase(
                $job,
                'awaiting_certs',
                'ok',
                'LE sync skipped — sync from SPA later ('.$e->getMessage().')'
            );
        }

        return $job;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCatalog(array $job): array
    {
        $this->registrar->moveTenant((string) $job['tenant_shortuid'], [
            'instance_id' => (string) $job['dest_instance_id'],
        ]);
        $job = $this->markPhase($job, 'catalog', 'ok');
        $this->jobs->writePublic($job);

        return $job;
    }

    /**
     * Source Phase 8: full tenant wipe via fleet DELETE, then cert sync + commit on source.
     *
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCleanup(array $job): array
    {
        $shortuid = (string) $job['tenant_shortuid'];
        $source = (string) $job['source_api_base_url'];
        $job = $this->markPhase($job, 'awaiting_cleanup', 'running', 'wiping source tenant');
        $this->jobs->writePublic($job);

        try {
            $this->nodeDelete($source, '/fleet/tenants/'.rawurlencode($shortuid));
        } catch (\RuntimeException $e) {
            // Idempotent retry: already wiped.
            if ($e->getCode() !== 404) {
                throw $e;
            }
        }

        // Cert sync is best-effort on source: wipe + commit clear orphans/dialplan.
        // LE/certbot flakiness must not leave the move stuck after a successful wipe.
        $certNote = 'cert sync skipped';
        $email = getenv('PBX3_LE_EMAIL') ?: '';
        if ($email !== '') {
            try {
                $this->nodePost($source, '/fleet/certificates/sync', [
                    'email' => $email,
                ]);
                $certNote = 'cert sync ok';
            } catch (\Throwable $e) {
                $certNote = 'LE sync skipped — sync from SPA later ('.$e->getMessage().')';
                error_log('[tenant-move] source cert sync after wipe: '.$e->getMessage());
            }
        }
        $this->nodePost($source, '/fleet/commit', []);

        $job = $this->markPhase($job, 'awaiting_cleanup', 'ok', 'source tenant wiped; commit ok; '.$certNote);

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
        $row = $phases[$phase] ?? [];
        $row['status'] = $status;
        if ($status === 'running') {
            $row['started_at'] = gmdate('Y-m-d\TH:i:s\Z');
        }
        if (in_array($status, ['ok', 'failed', 'skipped'], true)) {
            $row['finished_at'] = gmdate('Y-m-d\TH:i:s\Z');
        }
        if ($message !== null) {
            $row['message'] = $message;
        }
        $phases[$phase] = $row;
        $job['phases'] = $phases;

        return $job;
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
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function sbcPost(string $path, array $body): array
    {
        return $this->requestJson('POST', $this->sbcApiBase.$path, $body);
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
            $msg = is_array($decoded) ? ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded)) : (string) $res->getBody();
            throw new \RuntimeException("HTTP {$method} {$url} → {$code}: {$msg}", $code >= 400 && $code < 600 ? $code : 502);
        }

        return is_array($decoded) ? $decoded : [];
    }
}
