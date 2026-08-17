<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Persist tenant-delete-job.v0.json under tenants/{shortuid}/deletion/{job_id}/job.json.
 */
final class TenantDeleteJobStore
{
    private S3Client $s3;

    private string $bucket;

    public function __construct()
    {
        $bucket = getenv('PBX3_ORG_BUCKET') ?: '';
        if ($bucket === '') {
            throw new \RuntimeException('PBX3_ORG_BUCKET not configured', 503);
        }
        $this->bucket = $bucket;
        $this->s3 = S3ClientFactory::make();
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function create(array $body, S3Registrar $registrar): array
    {
        $shortuid = strtolower(trim((string) ($body['tenant_shortuid'] ?? '')));
        if ($shortuid === '') {
            throw new \InvalidArgumentException('tenant_shortuid required', 422);
        }

        $meta = $registrar->getTenant($shortuid);
        $status = strtolower((string) ($meta['status'] ?? 'active'));
        if ($status === 'decommissioned') {
            throw new \InvalidArgumentException("Tenant already decommissioned: {$shortuid}", 409);
        }

        $instanceId = (string) ($body['instance_id'] ?? $meta['instance_id'] ?? '');
        if ($instanceId === '') {
            throw new \InvalidArgumentException('instance_id missing on tenant meta', 422);
        }

        $catalog = $registrar->getCatalog();
        $apiBase = (string) ($body['api_base_url'] ?? '');
        $fqdn = (string) ($body['tenant_fqdn'] ?? $meta['fqdn'] ?? '');
        foreach ($catalog['instances'] ?? [] as $inst) {
            if (! is_array($inst)) {
                continue;
            }
            if ((string) ($inst['id'] ?? '') !== $instanceId) {
                continue;
            }
            if ($apiBase === '') {
                $apiBase = (string) ($inst['api_base_url'] ?? '');
            }
            break;
        }

        $jobId = (string) ($body['job_id'] ?? $this->newJobId());
        $now = $this->nowIso();
        $prefix = "tenants/{$shortuid}/deletion/{$jobId}/";

        $job = [
            'schema_version' => 1,
            'job_id' => $jobId,
            'tenant_shortuid' => $shortuid,
            'tenant_pkey' => $meta['cname'] ?? $meta['pkey'] ?? null,
            'tenant_fqdn' => $fqdn !== '' ? $fqdn : null,
            'instance_id' => $instanceId,
            'api_base_url' => $apiBase !== '' ? $apiBase : null,
            'state' => 'pending',
            'warnings' => [],
            'wipe_counts' => null,
            'mesh_prune' => null,
            'phases' => [],
            'error' => null,
            'rollback' => [
                'safe_to_abort' => true,
                'hint' => 'Job not started — abort is a no-op beyond marking aborted.',
            ],
            'next_human_action' => null,
            'created_by' => isset($body['created_by']) && is_string($body['created_by'])
                ? $body['created_by']
                : null,
            'last_action_by' => isset($body['created_by']) && is_string($body['created_by'])
                ? $body['created_by']
                : null,
            'created_at' => $now,
            'updated_at' => $now,
            'completed_at' => null,
            'staging' => ['prefix' => $prefix],
        ];

        $this->writeJob($shortuid, $jobId, $job);

        return $job;
    }

    /** @return array<string, mixed> */
    public function get(string $jobId, ?string $shortuid = null): array
    {
        if ($shortuid !== null && $shortuid !== '') {
            $job = $this->readJob($shortuid, $jobId);
            if ($job !== null) {
                return $job;
            }
            throw new \RuntimeException("Delete job not found: {$jobId}", 404);
        }

        $result = $this->s3->listObjectsV2([
            'Bucket' => $this->bucket,
            'Prefix' => 'tenants/',
            'Delimiter' => '/',
        ]);
        foreach ($result['CommonPrefixes'] ?? [] as $prefix) {
            $uid = basename(rtrim((string) $prefix['Prefix'], '/'));
            if ($uid === '' || str_starts_with($uid, '_')) {
                continue;
            }
            $job = $this->readJob($uid, $jobId);
            if ($job !== null) {
                return $job;
            }
        }

        throw new \RuntimeException("Delete job not found: {$jobId}", 404);
    }

    /**
     * @param  array<string, mixed>  $job
     */
    public function writePublic(array $job): void
    {
        $shortuid = (string) ($job['tenant_shortuid'] ?? '');
        $jobId = (string) ($job['job_id'] ?? '');
        if ($shortuid === '' || $jobId === '') {
            throw new \InvalidArgumentException('job_id and tenant_shortuid required', 422);
        }
        $job['updated_at'] = $this->nowIso();
        $this->writeJob($shortuid, $jobId, $job);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function list(int $limit = 50): array
    {
        $limit = max(1, min(200, $limit));
        $jobs = [];
        $token = null;

        do {
            $params = [
                'Bucket' => $this->bucket,
                'Prefix' => 'tenants/',
                'MaxKeys' => 200,
            ];
            if ($token !== null) {
                $params['ContinuationToken'] = $token;
            }
            $result = $this->s3->listObjectsV2($params);
            foreach ($result['Contents'] ?? [] as $obj) {
                $key = (string) ($obj['Key'] ?? '');
                if (! preg_match('#^tenants/([a-z0-9]+)/deletion/([A-Za-z0-9_-]+)/job\.json$#', $key, $m)) {
                    continue;
                }
                $job = $this->readJob($m[1], $m[2]);
                if ($job !== null) {
                    $jobs[] = $job;
                }
            }
            $token = ! empty($result['IsTruncated'])
                ? ($result['NextContinuationToken'] ?? null)
                : null;
        } while ($token !== null && count($jobs) < 500);

        usort($jobs, static function (array $a, array $b): int {
            $ua = (string) ($a['updated_at'] ?? $a['created_at'] ?? '');
            $ub = (string) ($b['updated_at'] ?? $b['created_at'] ?? '');

            return strcmp($ub, $ua);
        });

        return array_slice($jobs, 0, $limit);
    }

    /** @return array<string, mixed>|null */
    private function readJob(string $shortuid, string $jobId): ?array
    {
        $key = "tenants/{$shortuid}/deletion/{$jobId}/job.json";
        try {
            $result = $this->s3->getObject(['Bucket' => $this->bucket, 'Key' => $key]);
            $data = json_decode((string) $result['Body'], true);

            return is_array($data) ? $data : null;
        } catch (\Throwable) {
            return null;
        }
    }

    /** @param  array<string, mixed>  $job */
    private function writeJob(string $shortuid, string $jobId, array $job): void
    {
        $key = "tenants/{$shortuid}/deletion/{$jobId}/job.json";
        $this->s3->putObject([
            'Bucket' => $this->bucket,
            'Key' => $key,
            'Body' => json_encode($job, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT),
            'ContentType' => 'application/json',
        ]);
    }

    private function newJobId(): string
    {
        return 'tdj_'.bin2hex(random_bytes(12));
    }

    private function nowIso(): string
    {
        return gmdate('Y-m-d\TH:i:s\Z');
    }
}
