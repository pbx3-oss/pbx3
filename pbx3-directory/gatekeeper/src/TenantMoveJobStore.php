<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Persist tenant-move-job.v0.json under tenants/{shortuid}/migration/{job_id}/job.json.
 * Phase runners (node/SBC calls) land in a later slice — this is create/get/patch state.
 */
final class TenantMoveJobStore
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
        $region = getenv('AWS_DEFAULT_REGION') ?: 'us-east-1';
        $this->s3 = new S3Client([
            'version' => 'latest',
            'region' => $region,
        ]);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function create(array $body): array
    {
        foreach (['tenant_shortuid', 'source_instance_id', 'dest_instance_id'] as $key) {
            if (empty($body[$key])) {
                throw new \InvalidArgumentException("Missing required field: {$key}", 422);
            }
        }

        $shortuid = (string) $body['tenant_shortuid'];
        $jobId = (string) ($body['job_id'] ?? $this->newJobId());
        $now = $this->nowIso();
        $prefix = "tenants/{$shortuid}/migration/{$jobId}/";

        $job = [
            'schema_version' => 1,
            'job_id' => $jobId,
            'tenant_shortuid' => $shortuid,
            'tenant_fqdn' => $body['tenant_fqdn'] ?? null,
            'source_instance_id' => (string) $body['source_instance_id'],
            'dest_instance_id' => (string) $body['dest_instance_id'],
            'source_api_base_url' => $body['source_api_base_url'] ?? null,
            'dest_api_base_url' => $body['dest_api_base_url'] ?? null,
            'dest_sbc_dispatcher_setid' => isset($body['dest_sbc_dispatcher_setid'])
                ? (int) $body['dest_sbc_dispatcher_setid']
                : null,
            'previous_sbc_dispatcher_setid' => $body['previous_sbc_dispatcher_setid'] ?? null,
            'state' => 'pending',
            'posture' => $body['posture'] ?? 'sbc',
            'options' => [
                'include_recordings' => (bool) ($body['options']['include_recordings'] ?? false),
                'replace_on_dest' => (bool) ($body['options']['replace_on_dest'] ?? false),
            ],
            'staging' => [
                'prefix' => $prefix,
                'export_zip_key' => null,
            ],
            'phases' => [],
            'error' => null,
            'rollback' => [
                'safe_to_abort' => true,
                'hint' => 'Job not started — abort is a no-op beyond deleting job.json.',
            ],
            'next_human_action' => null,
            'created_at' => $now,
            'updated_at' => $now,
            'completed_at' => null,
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
            throw new \RuntimeException("Job not found: {$jobId}", 404);
        }

        // Scan tenant prefixes for job_id (lab-scale; fine for v0)
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

        throw new \RuntimeException("Job not found: {$jobId}", 404);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function patchState(string $jobId, array $body, ?string $shortuid = null): array
    {
        $job = $this->get($jobId, $shortuid);
        $shortuid = (string) $job['tenant_shortuid'];

        if (isset($body['state'])) {
            $job['state'] = (string) $body['state'];
        }
        if (array_key_exists('error', $body)) {
            $job['error'] = $body['error'];
        }
        if (array_key_exists('next_human_action', $body)) {
            $job['next_human_action'] = $body['next_human_action'];
        }
        if (isset($body['staging']) && is_array($body['staging'])) {
            $job['staging'] = array_merge($job['staging'] ?? [], $body['staging']);
        }
        if (isset($body['phases']) && is_array($body['phases'])) {
            $job['phases'] = array_merge((array) ($job['phases'] ?? []), $body['phases']);
        }
        if (isset($body['rollback']) && is_array($body['rollback'])) {
            $job['rollback'] = array_merge($job['rollback'] ?? [], $body['rollback']);
        }

        $terminal = ['completed', 'failed', 'aborted'];
        if (in_array($job['state'], $terminal, true)) {
            $job['completed_at'] = $this->nowIso();
            $job['rollback']['safe_to_abort'] = false;
        } elseif ($job['state'] === 'awaiting_cleanup') {
            $job['rollback']['safe_to_abort'] = true;
            $job['rollback']['hint'] = $job['rollback']['hint']
                ?? 'Source still intact until cleanup confirmed.';
        }

        $job['updated_at'] = $this->nowIso();
        $this->writeJob($shortuid, $jobId, $job);

        return $job;
    }

    /**
     * Persist a full job document (used by TenantMoveRunner).
     *
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
     * List move jobs (lab-scale: scan S3 for tenants/{shortuid}/migration/{jobId}/job.json).
     *
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
                if (! str_ends_with($key, '/job.json')) {
                    continue;
                }
                if (! preg_match('#^tenants/([a-z0-9]+)/migration/([A-Za-z0-9_-]+)/job\.json$#', $key, $m)) {
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
        $key = "tenants/{$shortuid}/migration/{$jobId}/job.json";
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
        $key = "tenants/{$shortuid}/migration/{$jobId}/job.json";
        $this->s3->putObject([
            'Bucket' => $this->bucket,
            'Key' => $key,
            'Body' => json_encode($job, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT),
            'ContentType' => 'application/json',
        ]);
    }

    private function newJobId(): string
    {
        return 'tmj_'.bin2hex(random_bytes(12));
    }

    private function nowIso(): string
    {
        return gmdate('Y-m-d\TH:i:s\Z');
    }
}
