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

    private const TENANT_HOME_KEY = 'catalog/tenant-home.json';

    /** @var list<string> */
    public const STATUSES = ['active', 'maintenance', 'decommissioned'];

    /** @var list<string> */
    private const PATCHABLE = [
        'label',
        'notes',
        'environment',
        'status',
        'fqdn',
        'api_base_url',
        'region',
        'org_id',
        'package_version',
        'sbc_dispatcher_setid',
        'sbc_backend_uri',
    ];

    public function __construct()
    {
        $bucket = getenv('PBX3_ORG_BUCKET') ?: '';
        if ($bucket === '') {
            throw new \RuntimeException('PBX3_ORG_BUCKET not configured', 503);
        }
        $this->bucket = $bucket;
        $this->s3 = S3ClientFactory::make();
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

    /**
     * Register or upsert an instance in the catalog.
     *
     * Body may include control keys (stripped before write):
     * - verify_up (bool): probe /up before write; SPA default true
     * - updated_by (string): actor email (also stamped from Auth in index)
     *
     * @param  array<string, mixed>  $record
     * @return array{catalog: array<string, mixed>, instance_meta: array<string, mixed>}
     */
    public function registerInstance(array $record): array
    {
        $verifyUp = ! empty($record['verify_up']);
        unset($record['verify_up']);

        $updatedBy = null;
        if (isset($record['updated_by']) && is_string($record['updated_by']) && $record['updated_by'] !== '') {
            $updatedBy = $record['updated_by'];
        }
        unset($record['updated_by']);

        foreach (['id', 'fqdn', 'api_base_url', 'label', 'status'] as $key) {
            if (empty($record[$key])) {
                throw new \InvalidArgumentException("Missing required field: {$key}", 422);
            }
        }
        $this->assertValidStatus((string) $record['status']);

        if ($verifyUp) {
            InstanceUpProbe::verify((string) $record['api_base_url']);
            $record['last_seen_at'] = $this->nowIso();
        }

        $now = $this->nowIso();
        if ($updatedBy !== null) {
            $record['updated_by'] = $updatedBy;
        }
        $record['updated_at'] = $now;

        $label = trim((string) ($record['label'] ?? ''));
        $apiBase = (string) ($record['api_base_url'] ?? '');
        if ($label !== '' && $apiBase !== '') {
            try {
                (new NodeSitenameClient())->putSitename($apiBase, $label);
            } catch (\Throwable $e) {
                // Register still writes catalog; node may be unreachable at first register.
                error_log('[gatekeeper] register sitename push failed: '.$e->getMessage());
            }
        }

        return $this->writeInstanceRecord($record, $now);
    }

    /**
     * Partial update of an existing catalog instance.
     *
     * @param  array<string, mixed>  $patch
     * @return array{catalog: array<string, mixed>, instance: array<string, mixed>, instance_meta: array<string, mixed>}
     */
    public function patchInstance(string $id, array $patch, ?string $updatedBy = null): array
    {
        $id = trim($id);
        if ($id === '') {
            throw new \InvalidArgumentException('Instance id required', 422);
        }

        $catalog = $this->getCatalog();
        $instances = $catalog['instances'] ?? [];
        $index = null;
        foreach ($instances as $i => $row) {
            if (($row['id'] ?? '') === $id) {
                $index = $i;
                break;
            }
        }
        if ($index === null) {
            throw new \RuntimeException("Instance not found: {$id}", 404);
        }

        $previousStatus = (string) ($instances[$index]['status'] ?? 'active');

        $apply = [];
        foreach (self::PATCHABLE as $key) {
            if (! array_key_exists($key, $patch)) {
                continue;
            }
            $apply[$key] = $patch[$key];
        }
        if ($apply === []) {
            throw new \InvalidArgumentException('No patchable fields provided', 422);
        }
        if (isset($apply['status'])) {
            $this->assertValidStatus((string) $apply['status']);
        }
        if (
            isset($apply['status'])
            && (string) $apply['status'] === 'decommissioned'
            && $previousStatus !== 'decommissioned'
        ) {
            $this->assertCanDecommissionInstance($id);
        }
        if (array_key_exists('sbc_dispatcher_setid', $apply) && $apply['sbc_dispatcher_setid'] !== null) {
            $apply['sbc_dispatcher_setid'] = (int) $apply['sbc_dispatcher_setid'];
        }

        // Friendly Name: push sitename to node before catalog write (fail whole save).
        if (array_key_exists('label', $apply)) {
            $label = trim((string) $apply['label']);
            if ($label === '') {
                throw new \InvalidArgumentException('label (friendly Name) required', 422);
            }
            $apiBase = (string) ($instances[$index]['api_base_url'] ?? '');
            (new NodeSitenameClient())->putSitename($apiBase, $label);
        }

        $now = $this->nowIso();
        $merged = array_merge($instances[$index], $apply);
        $merged['id'] = $id;
        $merged['updated_at'] = $now;
        if ($updatedBy !== null && $updatedBy !== '') {
            $merged['updated_by'] = $updatedBy;
        }

        $instances[$index] = $merged;
        $catalog['version'] = 1;
        $catalog['updated_at'] = $now;
        $catalog['instances'] = array_values($instances);
        $this->writeJson(self::CATALOG_KEY, $catalog);

        $meta = $this->syncMetaFromRecord($merged, $now);

        $newStatus = (string) ($merged['status'] ?? 'active');
        if ($previousStatus !== $newStatus) {
            try {
                NotifyDispatcher::fromEnv()->notifyInstanceLifecycle($merged, $previousStatus, $newStatus);
            } catch (\Throwable $e) {
                error_log('[gatekeeper-notify] lifecycle notify failed: '.$e->getMessage());
            }
        }

        return ['catalog' => $catalog, 'instance' => $merged, 'instance_meta' => $meta];
    }

    /**
     * Stamp last_seen_at after a successful scheduled /up probe (does not change updated_by).
     *
     * @return array{catalog: array<string, mixed>, instance: array<string, mixed>, instance_meta: array<string, mixed>}
     */
    public function touchLastSeenAt(string $id): array
    {
        $id = trim($id);
        if ($id === '') {
            throw new \InvalidArgumentException('Instance id required', 422);
        }

        $catalog = $this->getCatalog();
        $instances = $catalog['instances'] ?? [];
        $index = null;
        foreach ($instances as $i => $row) {
            if (($row['id'] ?? '') === $id) {
                $index = $i;
                break;
            }
        }
        if ($index === null) {
            throw new \RuntimeException("Instance not found: {$id}", 404);
        }

        $now = $this->nowIso();
        $merged = $instances[$index];
        $merged['last_seen_at'] = $now;
        $instances[$index] = $merged;
        $catalog['version'] = 1;
        $catalog['updated_at'] = $now;
        $catalog['instances'] = array_values($instances);
        $this->writeJson(self::CATALOG_KEY, $catalog);

        $meta = $this->syncMetaFromRecord($merged, $now);

        return ['catalog' => $catalog, 'instance' => $merged, 'instance_meta' => $meta];
    }

    /**
     * Soft decommission — status=decommissioned (SPA confirm required).
     *
     * @param  array<string, mixed>  $body
     * @return array{catalog: array<string, mixed>, instance: array<string, mixed>, instance_meta: array<string, mixed>}
     */
    public function decommissionInstance(string $id, array $body, ?string $updatedBy = null): array
    {
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to decommission', 422);
        }
        $notes = isset($body['notes']) && is_string($body['notes']) ? trim($body['notes']) : '';
        $patch = ['status' => 'decommissioned'];
        if ($notes !== '') {
            $patch['notes'] = $notes;
        } else {
            $patch['notes'] = 'Decommissioned '.$this->nowIso();
        }

        $this->assertCanDecommissionInstance($id);

        return $this->patchInstance($id, $patch, $updatedBy);
    }

    /**
     * Hard remove from catalog — decommissioned instances only (SPA / ops; mirrors unregister-instance.sh --remove).
     * Keeps instances/{id}/meta.json and S3 backups; drops catalog row.
     *
     * @param  array<string, mixed>  $body  confirm: true required; optional notes
     * @return array{catalog: array<string, mixed>, removed_id: string, instance_meta: array<string, mixed>}
     */
    public function removeInstanceFromCatalog(string $id, array $body, ?string $updatedBy = null): array
    {
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to remove instance from catalog', 422);
        }

        $id = trim($id);
        if ($id === '') {
            throw new \InvalidArgumentException('Instance id required', 422);
        }

        $catalog = $this->getCatalog();
        $instances = $catalog['instances'] ?? [];
        $index = null;
        $record = null;
        foreach ($instances as $i => $row) {
            if (($row['id'] ?? '') === $id) {
                $index = $i;
                $record = $row;
                break;
            }
        }
        if ($index === null || ! is_array($record)) {
            throw new \RuntimeException("Instance not found: {$id}", 404);
        }

        self::assertDecommissionedForCatalogRemove($record);

        $notes = isset($body['notes']) && is_string($body['notes']) ? trim($body['notes']) : '';
        if ($notes === '') {
            $notes = 'Removed from fleet catalog '.$this->nowIso();
        }

        $now = $this->nowIso();
        array_splice($instances, $index, 1);
        $catalog['version'] = 1;
        $catalog['updated_at'] = $now;
        $catalog['instances'] = array_values($instances);
        $this->writeJson(self::CATALOG_KEY, $catalog);

        $metaKey = "instances/{$id}/meta.json";
        $meta = $this->readJson($metaKey, []);
        if ($meta !== []) {
            $meta['status'] = 'decommissioned';
            $meta['updated_at'] = $now;
            $meta['notes'] = $notes;
            $meta['removed_from_catalog_at'] = $now;
            if ($updatedBy !== null && $updatedBy !== '') {
                $meta['updated_by'] = $updatedBy;
            }
            $this->writeJson($metaKey, $meta);
        }

        return ['catalog' => $catalog, 'removed_id' => $id, 'instance_meta' => $meta];
    }

    /**
     * @param  array<string, mixed>  $record
     */
    public static function assertDecommissionedForCatalogRemove(array $record): void
    {
        $status = strtolower((string) ($record['status'] ?? 'active'));
        if ($status !== 'decommissioned') {
            throw new \InvalidArgumentException(
                'Instance must be decommissioned before remove from catalog (Decom first)',
                422
            );
        }
    }

    /**
     * Active (non-decommissioned) tenants homed on this instance — RESTRICT gate for Decom (#5i).
     *
     * @param  list<array<string, mixed>>  $tenantMetas
     * @return list<array{shortuid: string, fqdn: string, pkey: string, cname: string}>
     */
    public static function activeTenantsForInstance(string $instanceId, array $tenantMetas): array
    {
        $instanceId = trim($instanceId);
        if ($instanceId === '') {
            return [];
        }

        $rows = [];
        foreach ($tenantMetas as $meta) {
            if (! is_array($meta)) {
                continue;
            }
            $status = strtolower((string) ($meta['status'] ?? 'active'));
            if ($status === 'decommissioned') {
                continue;
            }
            if (trim((string) ($meta['instance_id'] ?? '')) !== $instanceId) {
                continue;
            }
            $shortuid = strtolower(trim((string) ($meta['shortuid'] ?? $meta['tenant_shortuid'] ?? '')));
            if ($shortuid === '') {
                continue;
            }
            $fqdn = trim((string) ($meta['fqdn'] ?? $meta['cname'] ?? ''));
            $rows[] = [
                'shortuid' => $shortuid,
                'fqdn' => $fqdn !== '' ? $fqdn : $shortuid,
                'pkey' => trim((string) ($meta['pkey'] ?? '')),
                'cname' => trim((string) ($meta['cname'] ?? '')),
            ];
        }
        usort($rows, static fn (array $a, array $b): int => strcmp($a['shortuid'], $b['shortuid']));

        return $rows;
    }

    /**
     * Block instance Decom / status→decommissioned while active tenants still home here.
     *
     * @param  list<array<string, mixed>>|null  $tenantMetas
     */
    public function assertCanDecommissionInstance(string $instanceId, ?array $tenantMetas = null): void
    {
        self::assertCanDecommissionInstanceWithMetas($instanceId, $tenantMetas ?? $this->listTenants());
    }

    /**
     * @param  list<array<string, mixed>>  $tenantMetas
     */
    public static function assertCanDecommissionInstanceWithMetas(string $instanceId, array $tenantMetas): void
    {
        $blocking = self::activeTenantsForInstance($instanceId, $tenantMetas);
        if ($blocking === []) {
            return;
        }

        $labels = array_map(
            static function (array $tenant): string {
                $shortuid = (string) $tenant['shortuid'];
                $pkey = (string) ($tenant['pkey'] ?? '');
                if ($pkey !== '' && $pkey !== $shortuid) {
                    return $shortuid.' ('.$pkey.')';
                }

                return $shortuid;
            },
            $blocking
        );

        throw new CatalogIntegrityException(
            'Cannot decommission instance while active tenants remain (move or delete each tenant first): '
            .implode(', ', $labels),
            $blocking
        );
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
        $this->rebuildTenantHomeIndex();

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
        $this->rebuildTenantHomeIndex();

        return $meta;
    }

    /**
     * Soft-decommission a tenant in catalog (Fleet Delete). Keeps meta.json for audit.
     *
     * @param  array<string, mixed>  $body  confirm: true required; optional notes
     * @return array<string, mixed>
     */
    public function decommissionTenant(string $shortuid, array $body, ?string $updatedBy = null): array
    {
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to decommission tenant', 422);
        }

        $metaKey = "tenants/{$shortuid}/meta.json";
        $meta = $this->readJson($metaKey, []);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }

        $now = $this->nowIso();
        $notes = isset($body['notes']) && is_string($body['notes']) ? trim($body['notes']) : '';
        $meta['status'] = 'decommissioned';
        $meta['decommissioned_at'] = $now;
        $meta['updated_at'] = $now;
        $meta['notes'] = $notes !== '' ? $notes : ('Decommissioned '.$now);
        if ($updatedBy !== null && $updatedBy !== '') {
            $meta['updated_by'] = $updatedBy;
        }
        $this->writeJson($metaKey, $meta);
        $this->rebuildTenantHomeIndex();

        return $meta;
    }

    /** @return array<string, mixed> */
    public function getTenant(string $shortuid): array
    {
        $meta = $this->readJson("tenants/{$shortuid}/meta.json", []);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }

        return $meta;
    }

    /**
     * B′ login homing — compiled public rollup for SPA tenant-id resolve.
     * Source of truth remains tenants/{shortuid}/meta.json.
     *
     * @return array{version: int, updated_at: string, tenants: list<array{shortuid: string, cname: string, instance_id: string}>}
     */
    public function rebuildTenantHomeIndex(): array
    {
        $index = self::buildTenantHomeIndex($this->listTenants(), $this->nowIso());
        $this->writeJson(self::TENANT_HOME_KEY, $index);

        return $index;
    }

    /**
     * Pure helper for tests — omit decommissioned; require shortuid + instance_id.
     *
     * @param  list<array<string, mixed>>  $tenantMetas
     * @return array{version: int, updated_at: string, tenants: list<array{shortuid: string, cname: string, instance_id: string}>}
     */
    public static function buildTenantHomeIndex(array $tenantMetas, ?string $updatedAt = null): array
    {
        $rows = [];
        foreach ($tenantMetas as $meta) {
            if (! is_array($meta)) {
                continue;
            }
            $status = strtolower((string) ($meta['status'] ?? 'active'));
            if ($status === 'decommissioned') {
                continue;
            }
            $shortuid = strtolower(trim((string) ($meta['shortuid'] ?? $meta['tenant_shortuid'] ?? '')));
            $instanceId = trim((string) ($meta['instance_id'] ?? ''));
            if ($shortuid === '' || $instanceId === '') {
                continue;
            }
            $cname = trim((string) ($meta['cname'] ?? $meta['fqdn'] ?? ''));
            if ($cname === '') {
                $cname = $shortuid;
            }
            $rows[] = [
                'shortuid' => $shortuid,
                'cname' => $cname,
                'instance_id' => $instanceId,
            ];
        }
        usort($rows, static fn (array $a, array $b): int => strcmp($a['shortuid'], $b['shortuid']));

        return [
            'version' => 1,
            'updated_at' => $updatedAt ?? gmdate('Y-m-d\TH:i:s\Z'),
            'tenants' => $rows,
        ];
    }

    /** @return array<string, mixed> */
    public function getTenantMeta(string $shortuid): array
    {
        return $this->readJson("tenants/{$shortuid}/meta.json", []);
    }

    /**
     * S10.5 — tenants/{shortuid}/dids.json (empty inventory if missing).
     *
     * @return array{tenant_shortuid: string, updated_at: string, dids: list<array<string, mixed>>}
     */
    public function getDidInventory(string $shortuid): array
    {
        $inv = $this->readJson("tenants/{$shortuid}/dids.json", []);
        if ($inv === []) {
            return [
                'tenant_shortuid' => $shortuid,
                'updated_at' => $this->nowIso(),
                'dids' => [],
            ];
        }
        if (! isset($inv['dids']) || ! is_array($inv['dids'])) {
            $inv['dids'] = [];
        }
        $inv['tenant_shortuid'] = $shortuid;

        return $inv;
    }

    /** @param array<string, mixed> $inventory */
    public function putDidInventory(string $shortuid, array $inventory): void
    {
        $inventory['tenant_shortuid'] = $shortuid;
        if (! isset($inventory['updated_at'])) {
            $inventory['updated_at'] = $this->nowIso();
        }
        if (! isset($inventory['dids']) || ! is_array($inventory['dids'])) {
            $inventory['dids'] = [];
        }
        $this->writeJson("tenants/{$shortuid}/dids.json", $inventory);
    }

    /** @param array<string, mixed> $index */
    public function putDidIndex(array $index): void
    {
        $this->writeJson('catalog/did-index.json', $index);
    }

    /**
     * Replace tenants/{shortuid}/meta.json (Gatekeeper sole writer).
     *
     * @param  array<string, mixed>  $meta
     * @return array<string, mixed>
     */
    public function putTenantMeta(string $shortuid, array $meta): array
    {
        $shortuid = strtolower(trim($shortuid));
        if ($shortuid === '' || ! preg_match('/^[a-z0-9]+$/', $shortuid)) {
            throw new \InvalidArgumentException('shortuid required (lowercase alnum)', 422);
        }
        $meta['shortuid'] = $shortuid;
        if (! isset($meta['tenant_shortuid'])) {
            $meta['tenant_shortuid'] = $shortuid;
        }
        if (! isset($meta['updated_at'])) {
            $meta['updated_at'] = $this->nowIso();
        }
        $this->writeJson("tenants/{$shortuid}/meta.json", $meta);

        return $meta;
    }

    private const DIAL_COHORT_INDEX_KEY = 'catalog/dial-cohort-index.json';

    /** @return array<string, mixed> */
    public function getDialCohort(string $id): array
    {
        $id = trim($id);
        if ($id === '') {
            return [];
        }

        return $this->readJson('catalog/dial-cohorts/'.$id.'.json', []);
    }

    /** @param array<string, mixed> $doc */
    public function putDialCohort(string $id, array $doc): void
    {
        $id = trim($id);
        if ($id === '') {
            throw new \InvalidArgumentException('cohort id required', 422);
        }
        $doc['id'] = $id;
        $this->writeJson('catalog/dial-cohorts/'.$id.'.json', $doc);
    }

    /** @return array{version: int, updated_at: string, cohorts: list<array<string, mixed>>} */
    public function getDialCohortIndex(): array
    {
        $index = $this->readJson(self::DIAL_COHORT_INDEX_KEY, []);
        if ($index === []) {
            return [
                'version' => 1,
                'updated_at' => $this->nowIso(),
                'cohorts' => [],
            ];
        }
        if (! isset($index['cohorts']) || ! is_array($index['cohorts'])) {
            $index['cohorts'] = [];
        }
        $index['version'] = 1;

        return $index;
    }

    /** @param array<string, mixed> $index */
    public function putDialCohortIndex(array $index): void
    {
        $index['version'] = 1;
        if (! isset($index['updated_at'])) {
            $index['updated_at'] = $this->nowIso();
        }
        if (! isset($index['cohorts']) || ! is_array($index['cohorts'])) {
            $index['cohorts'] = [];
        }
        $this->writeJson(self::DIAL_COHORT_INDEX_KEY, $index);
    }

    private const VELOCITY_POLICY_KEY = 'catalog/velocity-policy.json';

    /** @return array<string, mixed> empty when missing */
    public function getVelocityPolicy(): array
    {
        return $this->readJson(self::VELOCITY_POLICY_KEY, []);
    }

    /** @param array<string, mixed> $doc */
    public function putVelocityPolicy(array $doc): void
    {
        $this->writeJson(self::VELOCITY_POLICY_KEY, $doc);
    }

    /**
     * List cohort document ids under catalog/dial-cohorts/*.json (excludes jobs/).
     *
     * @return list<string>
     */
    public function listDialCohortIds(): array
    {
        $result = $this->s3->listObjectsV2([
            'Bucket' => $this->bucket,
            'Prefix' => 'catalog/dial-cohorts/',
        ]);
        $ids = [];
        foreach ($result['Contents'] ?? [] as $obj) {
            $key = (string) ($obj['Key'] ?? '');
            // catalog/dial-cohorts/{id}.json — skip nested jobs/
            if (! preg_match('#^catalog/dial-cohorts/([^/]+)\.json$#', $key, $m)) {
                continue;
            }
            $ids[] = $m[1];
        }
        sort($ids);

        return $ids;
    }

    /** @return array<string, mixed> */
    public function getDialCohortJob(string $cohortId, string $jobId): array
    {
        $cohortId = trim($cohortId);
        $jobId = trim($jobId);
        if ($cohortId === '' || $jobId === '') {
            return [];
        }

        return $this->readJson("catalog/dial-cohorts/{$cohortId}/jobs/{$jobId}.json", []);
    }

    /** @param array<string, mixed> $job */
    public function putDialCohortJob(string $cohortId, string $jobId, array $job): void
    {
        $cohortId = trim($cohortId);
        $jobId = trim($jobId);
        if ($cohortId === '' || $jobId === '') {
            throw new \InvalidArgumentException('cohort_id and job_id required', 422);
        }
        $this->writeJson("catalog/dial-cohorts/{$cohortId}/jobs/{$jobId}.json", $job);
    }

    /**
     * @return list<string>
     */
    public function listDialCohortJobIds(string $cohortId): array
    {
        $cohortId = trim($cohortId);
        if ($cohortId === '') {
            return [];
        }
        $result = $this->s3->listObjectsV2([
            'Bucket' => $this->bucket,
            'Prefix' => "catalog/dial-cohorts/{$cohortId}/jobs/",
        ]);
        $ids = [];
        foreach ($result['Contents'] ?? [] as $obj) {
            $key = (string) ($obj['Key'] ?? '');
            if (preg_match('#/jobs/([^/]+)\.json$#', $key, $m)) {
                $ids[] = $m[1];
            }
        }
        sort($ids);

        return $ids;
    }

    public function nowIso(): string
    {
        return gmdate('Y-m-d\TH:i:s\Z');
    }

    /**
     * Pure helper for tests — merge patch onto a catalog instance row.
     *
     * @param  array<string, mixed>  $existing
     * @param  array<string, mixed>  $patch
     * @return array<string, mixed>
     */
    public static function mergeInstancePatch(array $existing, array $patch): array
    {
        $apply = [];
        foreach (self::PATCHABLE as $key) {
            if (array_key_exists($key, $patch)) {
                $apply[$key] = $patch[$key];
            }
        }
        if (isset($apply['status']) && ! in_array((string) $apply['status'], self::STATUSES, true)) {
            throw new \InvalidArgumentException('Invalid status: '.$apply['status'], 422);
        }

        return array_merge($existing, $apply);
    }

    private function assertValidStatus(string $status): void
    {
        if (! in_array($status, self::STATUSES, true)) {
            throw new \InvalidArgumentException(
                'Invalid status: '.$status.' (expected '.implode('|', self::STATUSES).')',
                422
            );
        }
    }

    /**
     * @param  array<string, mixed>  $record
     * @return array{catalog: array<string, mixed>, instance_meta: array<string, mixed>}
     */
    private function writeInstanceRecord(array $record, string $now): array
    {
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
        $catalog['updated_at'] = $now;
        $catalog['instances'] = array_values($instances);
        $this->writeJson(self::CATALOG_KEY, $catalog);

        $meta = $this->syncMetaFromRecord($record, $now);

        return ['catalog' => $catalog, 'instance_meta' => $meta];
    }

    /**
     * @param  array<string, mixed>  $record
     * @return array<string, mixed>
     */
    private function syncMetaFromRecord(array $record, string $now): array
    {
        $id = (string) $record['id'];
        $metaKey = "instances/{$id}/meta.json";
        $existing = $this->readJson($metaKey, []);
        $meta = array_merge($existing, [
            'id' => $id,
            'fqdn' => $record['fqdn'] ?? ($existing['fqdn'] ?? ''),
            'api_base_url' => $record['api_base_url'] ?? ($existing['api_base_url'] ?? ''),
            'label' => $record['label'] ?? ($existing['label'] ?? ''),
            'status' => $record['status'] ?? ($existing['status'] ?? 'active'),
            'created_at' => $existing['created_at'] ?? $now,
            'updated_at' => $now,
        ]);
        foreach (['environment', 'notes', 'region', 'org_id', 'package_version', 'updated_by', 'last_seen_at', 'sbc_dispatcher_setid', 'sbc_backend_uri'] as $opt) {
            if (array_key_exists($opt, $record)) {
                $meta[$opt] = $record[$opt];
            }
        }
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

}
