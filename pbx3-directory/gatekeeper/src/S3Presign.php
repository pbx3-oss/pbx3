<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Issue scoped presigned URLs for tenant migration staging only (§2.6.1 / S8.10).
 * Allowed keys: tenants/{shortuid}/migration/{job_id}/…
 */
final class S3Presign
{
    private S3Client $s3;

    private string $bucket;

    private const DEFAULT_TTL_SECONDS = 900;

    private const MAX_TTL_SECONDS = 3600;

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
     * @return array{url: string, method: string, key: string, expires_in: int, bucket: string}
     */
    public function create(array $body): array
    {
        $method = strtoupper((string) ($body['method'] ?? 'PUT'));
        if (! in_array($method, ['PUT', 'GET'], true)) {
            throw new \InvalidArgumentException('method must be PUT or GET', 422);
        }

        $key = (string) ($body['key'] ?? '');
        if ($key === '' || ! $this->isAllowedMigrationKey($key)) {
            throw new \InvalidArgumentException(
                'key must be under tenants/{shortuid}/migration/{job_id}/',
                422
            );
        }

        $ttl = (int) ($body['expires_in'] ?? self::DEFAULT_TTL_SECONDS);
        if ($ttl < 60) {
            $ttl = 60;
        }
        if ($ttl > self::MAX_TTL_SECONDS) {
            $ttl = self::MAX_TTL_SECONDS;
        }

        $commandName = $method === 'PUT' ? 'PutObject' : 'GetObject';
        $command = $this->s3->getCommand($commandName, [
            'Bucket' => $this->bucket,
            'Key' => $key,
        ]);
        $request = $this->s3->createPresignedRequest($command, "+{$ttl} seconds");

        return [
            'url' => (string) $request->getUri(),
            'method' => $method,
            'key' => $key,
            'expires_in' => $ttl,
            'bucket' => $this->bucket,
        ];
    }

    private function isAllowedMigrationKey(string $key): bool
    {
        // tenants/{shortuid}/migration/{job_id}/… — no path traversal
        if (str_contains($key, '..') || str_starts_with($key, '/')) {
            return false;
        }

        return (bool) preg_match(
            '#^tenants/[a-z0-9]+/migration/[A-Za-z0-9_-]+/.+#',
            $key
        );
    }
}
