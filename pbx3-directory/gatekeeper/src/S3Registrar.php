<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Ports pbx3-directory/tools registrar shell logic to S3 API (Phase B′).
 */
final class S3Registrar
{
    private S3Client $s3;

    private string $bucket;

    private const CATALOG_KEY = 'catalog/instance-index.json';

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

    /** @return array<string, mixed> */
    public function getCatalog(): array
    {
        return $this->readJson(self::CATALOG_KEY, [
            'version' => 1,
            'updated_at' => $this->nowIso(),
            'instances' => [],
        ]);
    }

    /** @return list<array<string, mixed>> */
    public function listTenants(): array
    {
        $result = $this->s3->listObjectsV2([
            'Bucket' => $this->bucket,
            'Prefix' => 'tenants/',
            'Delimiter' => '/',
        ]);

        $tenants = [];
        foreach ($result['CommonPrefixes'] ?? [] as $prefix) {
            $shortuid = basename(rtrim((string) $prefix['Prefix'], '/'));
            if ($shortuid === '' || str_starts_with($shortuid, '_')) {
                continue;
            }
            $meta = $this->readJson("tenants/{$shortuid}/meta.json", []);
            if ($meta !== []) {
                $tenants[] = $meta;
            }
        }

        usort($tenants, static fn (array $a, array $b): int => strcmp((string) ($a['shortuid'] ?? ''), (string) ($b['shortuid'] ?? '')));

        return $tenants;
    }

    /** @param array<string, mixed> $record */
    public function registerInstance(array $record): array
    {
        foreach (['id', 'fqdn', 'api_base_url', 'label', 'status'] as $key) {
            if (empty($record[$key])) {
                throw new \InvalidArgumentException("Missing required field: {$key}", 422);
            }
        }

        $catalog = $this->getCatalog();
        $instances = $catalog['instances'] ?? [];
        $found = false;
        foreach ($instances as $i => $row) {
            if (($row['id'] ?? '') === $record['id']) {
                $instances[$i] = array_merge($row, $record);
                $found = true;
                break;
            }
        }
        if (! $found) {
            $instances[] = $record;
        }

        $catalog['version'] = 1;
        $catalog['updated_at'] = $this->nowIso();
        $catalog['instances'] = array_values($instances);
        $this->writeJson(self::CATALOG_KEY, $catalog);

        $id = (string) $record['id'];
        $metaKey = "instances/{$id}/meta.json";
        $existing = $this->readJson($metaKey, []);
        $meta = array_merge($existing, [
            'id' => $id,
            'fqdn' => $record['fqdn'],
            'api_base_url' => $record['api_base_url'],
            'label' => $record['label'],
            'status' => $record['status'],
            'created_at' => $existing['created_at'] ?? $this->nowIso(),
            'updated_at' => $this->nowIso(),
        ]);
        $this->writeJson($metaKey, $meta);

        return ['catalog' => $catalog, 'instance_meta' => $meta];
    }

    /** @param array<string, mixed> $record */
    public function registerTenant(array $record): array
    {
        foreach (['shortuid', 'instance_id', 'fqdn', 'status'] as $key) {
            if (empty($record[$key])) {
                throw new \InvalidArgumentException("Missing required field: {$key}", 422);
            }
        }

        $shortuid = (string) $record['shortuid'];
        $now = $this->nowIso();
        $metaKey = "tenants/{$shortuid}/meta.json";
        $existing = $this->readJson($metaKey, []);
        $meta = array_merge($existing, $record, [
            'shortuid' => $shortuid,
            'created_at' => $existing['created_at'] ?? $now,
            'updated_at' => $now,
        ]);
        $this->writeJson($metaKey, $meta);

        return $meta;
    }

    /** @param array<string, mixed> $body */
    public function moveTenant(string $shortuid, array $body): array
    {
        $instanceId = (string) ($body['instance_id'] ?? '');
        if ($instanceId === '') {
            throw new \InvalidArgumentException('instance_id required', 422);
        }

        $metaKey = "tenants/{$shortuid}/meta.json";
        $meta = $this->readJson($metaKey, []);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }

        $previous = (string) ($meta['instance_id'] ?? '');
        $now = $this->nowIso();
        $meta['previous_instance_id'] = $previous !== '' ? $previous : null;
        $meta['instance_id'] = $instanceId;
        $meta['moved_at'] = $now;
        $meta['updated_at'] = $now;
        $this->writeJson($metaKey, $meta);

        return $meta;
    }

    /** @param array<string, mixed> $default */
    private function readJson(string $key, array $default): array
    {
        try {
            $result = $this->s3->getObject(['Bucket' => $this->bucket, 'Key' => $key]);
            $data = json_decode((string) $result['Body'], true);

            return is_array($data) ? $data : $default;
        } catch (\Throwable) {
            return $default;
        }
    }

    /** @param array<string, mixed> $data */
    private function writeJson(string $key, array $data): void
    {
        $this->s3->putObject([
            'Bucket' => $this->bucket,
            'Key' => $key,
            'Body' => json_encode($data, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT),
            'ContentType' => 'application/json',
        ]);
    }

    private function nowIso(): string
    {
        return gmdate('Y-m-d\TH:i:s\Z');
    }
}
