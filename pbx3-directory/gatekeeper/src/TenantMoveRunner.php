<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Advance a tenant-move job through automated phases until a human gate or failure.
 *
 * Human gates: verifying (operator confirms test call), awaiting_cleanup (source delete).
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
        $this->sbcApiBase = rtrim(getenv('PBX3_SBC_ADMIN_API_URL') ?: '', '/');
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
            $job = $this->setState($job, 'awaiting_cleanup', 'Confirm delete of tenant on source (irreversible).');

            return $job;
        }

        if ($gate === 'cleanup') {
            if ($state !== 'awaiting_cleanup') {
                throw new \InvalidArgumentException("Job not in awaiting_cleanup (state={$state})", 409);
            }
            $job = $this->phaseCleanup($job);
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

            return $job;
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
            throw new \RuntimeException('PBX3_SBC_ADMIN_API_URL not set — cannot cutover');
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
        $this->nodePost((string) $job['dest_api_base_url'], '/fleet/certificates/sync', [
            'email' => $email,
        ]);

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
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function phaseCleanup(array $job): array
    {
        $shortuid = (string) $job['tenant_shortuid'];
        $this->nodeDelete((string) $job['source_api_base_url'], '/fleet/tenants/'.rawurlencode($shortuid));
        $job = $this->markPhase($job, 'awaiting_cleanup', 'ok', 'source tenant deleted');

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
