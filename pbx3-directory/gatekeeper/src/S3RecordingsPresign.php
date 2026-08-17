<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Issue scoped presigned URLs for call recordings on PBX3_RECORDINGS_BUCKET (S7).
 * Allowed keys: tenants/{shortuid}/recordings/… on the dedicated recordings bucket only.
 */
final class S3RecordingsPresign
{
    private S3Client $s3;

    private string $bucket;

    private const DEFAULT_TTL_SECONDS = 900;

    private const MAX_TTL_SECONDS = 3600;

    public function __construct()
    {
        $bucket = getenv('PBX3_RECORDINGS_BUCKET') ?: '';
        if ($bucket === '') {
            throw new \RuntimeException('PBX3_RECORDINGS_BUCKET not configured', 503);
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
        if ($key === '' || ! self::isAllowedRecordingsKey($key)) {
            throw new \InvalidArgumentException(
                'key must be under tenants/{shortuid}/recordings/',
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
        $params = [
            'Bucket' => $this->bucket,
            'Key' => $key,
        ];

        // Allow nodes to tag class=recording on PUT for lifecycle (S7.4).
        if ($method === 'PUT' && ! empty($body['tagging'])) {
            $params['Tagging'] = (string) $body['tagging'];
        }

        $command = $this->s3->getCommand($commandName, $params);
        $request = $this->s3->createPresignedRequest($command, "+{$ttl} seconds");

        return [
            'url' => (string) $request->getUri(),
            'method' => $method,
            'key' => $key,
            'expires_in' => $ttl,
            'bucket' => $this->bucket,
        ];
    }

    /** @internal public for unit tests */
    public static function isAllowedRecordingsKey(string $key): bool
    {
        if (str_contains($key, '..') || str_starts_with($key, '/')) {
            return false;
        }

        // tenants/{shortuid}/recordings/… — shortuid lowercase alnum; path after recordings required
        return (bool) preg_match(
            '#^tenants/[a-z0-9]+/recordings/.+#',
            $key
        );
    }
}
