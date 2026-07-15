<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * S10.5 — catalog DID ownership (HoR) + optional SBC projection.
 *
 * Authored: tenants/{shortuid}/dids.json
 * Compiled: catalog/did-index.json
 * Edge: SbcFleetClient.projectDids → inbound dr_rules
 */
final class DidInventory
{
    /** @var list<string> */
    public const STATUSES = ['active', 'reserved', 'porting', 'released'];

    /** Statuses that count as "owned" for uniqueness. */
    /** @var list<string> */
    public const OWNING_STATUSES = ['active', 'reserved', 'porting'];

    public function __construct(
        private readonly S3Registrar $registrar,
    ) {
    }

    /**
     * Fleet-wide flat list for SPA (ownership + homing hint).
     *
     * @return array{updated_at: string, dids: list<array<string, mixed>>}
     */
    public function listAll(): array
    {
        $tenants = $this->registrar->listTenants();
        $catalog = $this->registrar->getCatalog();
        $instancesById = [];
        foreach ($catalog['instances'] ?? [] as $row) {
            if (is_array($row) && isset($row['id'])) {
                $instancesById[(string) $row['id']] = $row;
            }
        }

        $flat = [];
        foreach ($tenants as $meta) {
            $shortuid = (string) ($meta['shortuid'] ?? '');
            if ($shortuid === '') {
                continue;
            }
            $inventory = $this->registrar->getDidInventory($shortuid);
            $instanceId = (string) ($meta['instance_id'] ?? '');
            $instance = $instancesById[$instanceId] ?? [];
            foreach ($inventory['dids'] ?? [] as $did) {
                if (! is_array($did)) {
                    continue;
                }
                $flat[] = [
                    'e164' => (string) ($did['e164'] ?? ''),
                    'e164_key' => self::e164Key((string) ($did['e164'] ?? '')),
                    'sip_prefix' => isset($did['sip_prefix']) ? (string) $did['sip_prefix'] : null,
                    'tenant_shortuid' => $shortuid,
                    'tenant_label' => (string) ($meta['label'] ?? $meta['pkey'] ?? $shortuid),
                    'tenant_fqdn' => (string) ($meta['fqdn'] ?? ''),
                    'instance_id' => $instanceId,
                    'sbc_dispatcher_setid' => $instance['sbc_dispatcher_setid'] ?? null,
                    'status' => (string) ($did['status'] ?? ''),
                    'carrier' => $did['carrier'] ?? null,
                    'label' => $did['label'] ?? null,
                    'notes' => $did['notes'] ?? null,
                    'assigned_at' => $did['assigned_at'] ?? null,
                    'updated_at' => $did['updated_at'] ?? null,
                ];
            }
        }

        usort($flat, static function (array $a, array $b): int {
            return strcmp((string) $a['e164'], (string) $b['e164']);
        });

        return [
            'updated_at' => $this->registrar->nowIso(),
            'dids' => $flat,
        ];
    }

    /**
     * Assign (or reassign) one E.164 to a tenant in the catalog.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function assign(array $body): array
    {
        $e164 = self::normalizeE164((string) ($body['e164'] ?? ''));
        $tenant = strtolower(trim((string) ($body['tenant_shortuid'] ?? '')));
        if ($tenant === '' || ! preg_match('/^[a-z0-9]+$/', $tenant)) {
            throw new \InvalidArgumentException('tenant_shortuid required (lowercase alnum)', 422);
        }

        $meta = $this->registrar->getTenantMeta($tenant);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$tenant}", 404);
        }

        $status = (string) ($body['status'] ?? 'active');
        if (! in_array($status, self::STATUSES, true)) {
            throw new \InvalidArgumentException(
                'Invalid status (expected '.implode('|', self::STATUSES).')',
                422
            );
        }

        $reassign = ! empty($body['reassign']);
        $existing = $this->findOwner($e164);

        if ($existing !== null
            && $existing['tenant_shortuid'] !== $tenant
            && in_array($existing['status'], self::OWNING_STATUSES, true)
            && ! $reassign
        ) {
            throw new \RuntimeException(
                "DID {$e164} already owned by tenant {$existing['tenant_shortuid']} — pass reassign: true",
                409
            );
        }

        $now = $this->registrar->nowIso();
        $record = [
            'e164' => $e164,
            'status' => $status,
            'updated_at' => $now,
        ];
        foreach (['carrier', 'label', 'notes'] as $opt) {
            if (isset($body[$opt]) && is_string($body[$opt]) && trim($body[$opt]) !== '') {
                $record[$opt] = trim($body[$opt]);
            }
        }
        if (isset($body['sip_prefix']) && is_string($body['sip_prefix']) && trim($body['sip_prefix']) !== '') {
            $sipPrefix = preg_replace('/\D+/', '', trim($body['sip_prefix'])) ?? '';
            if ($sipPrefix === '') {
                throw new \InvalidArgumentException('sip_prefix must be digits', 422);
            }
            $record['sip_prefix'] = $sipPrefix;
        }
        if ($existing === null || $existing['tenant_shortuid'] !== $tenant) {
            $record['assigned_at'] = $now;
        } elseif (! empty($existing['assigned_at'])) {
            $record['assigned_at'] = $existing['assigned_at'];
        } else {
            $record['assigned_at'] = $now;
        }

        $previous = null;
        if ($existing !== null && $existing['tenant_shortuid'] !== $tenant) {
            $previous = $existing['tenant_shortuid'];
            $this->removeDidFromTenant($previous, $e164);
        }

        $inventory = $this->upsertDidOnTenant($tenant, $record);
        $index = $this->compileAndWriteIndex();

        $out = [
            'ok' => true,
            'did' => $record,
            'tenant_shortuid' => $tenant,
            'previous_tenant_shortuid' => $previous,
            'inventory' => $inventory,
            'did_index' => $index,
            'sbc_projected' => false,
        ];

        $doProject = ! array_key_exists('project', $body) || ! empty($body['project']);
        if ($doProject) {
            $tenants = array_values(array_filter([$tenant, $previous]));
            $out['sbc'] = $this->projectToSbc(new SbcFleetClient(), $tenants);
            $out['sbc_projected'] = (bool) ($out['sbc']['ok'] ?? false);
        }

        return $out;
    }

    /**
     * Soft-release: mark released (or drop) so another tenant can take ownership.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function release(array $body): array
    {
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to release', 422);
        }
        $e164 = self::normalizeE164((string) ($body['e164'] ?? ''));
        $existing = $this->findOwner($e164);
        if ($existing === null) {
            throw new \RuntimeException("DID not found in catalog: {$e164}", 404);
        }

        $shortuid = $existing['tenant_shortuid'];
        $inventory = $this->registrar->getDidInventory($shortuid);
        $now = $this->registrar->nowIso();
        $dids = [];
        $hard = ! empty($body['remove']);
        foreach ($inventory['dids'] ?? [] as $did) {
            if (! is_array($did)) {
                continue;
            }
            if (self::e164Key((string) ($did['e164'] ?? '')) !== self::e164Key($e164)) {
                $dids[] = $did;
                continue;
            }
            if (! $hard) {
                $did['status'] = 'released';
                $did['updated_at'] = $now;
                $dids[] = $did;
            }
        }
        $inventory['dids'] = array_values($dids);
        $inventory['updated_at'] = $now;
        $inventory['tenant_shortuid'] = $shortuid;
        $this->registrar->putDidInventory($shortuid, $inventory);
        $index = $this->compileAndWriteIndex();

        $out = [
            'ok' => true,
            'e164' => $e164,
            'tenant_shortuid' => $shortuid,
            'removed' => $hard,
            'inventory' => $inventory,
            'did_index' => $index,
            'sbc_projected' => false,
        ];

        $doProject = ! array_key_exists('project', $body) || ! empty($body['project']);
        if ($doProject) {
            $out['sbc'] = $this->projectToSbc(new SbcFleetClient(), [$shortuid]);
            $out['sbc_projected'] = (bool) ($out['sbc']['ok'] ?? false);
        }

        return $out;
    }

    /**
     * Project catalog DID rows to SBC (one or more tenants, or all).
     *
     * @param  list<string>|null  $tenantFilter  null = all tenants with dids.json
     * @return array<string, mixed>
     */
    public function projectToSbc(SbcFleetClient $sbc, ?array $tenantFilter = null, bool $dryRun = false): array
    {
        $list = $this->listAll();
        $payload = [];
        $filter = $tenantFilter === null
            ? null
            : array_fill_keys(array_map('strval', $tenantFilter), true);

        foreach ($list['dids'] as $row) {
            $tenant = (string) ($row['tenant_shortuid'] ?? '');
            if ($filter !== null && ! isset($filter[$tenant])) {
                continue;
            }
            $payload[] = [
                'e164' => $row['e164'],
                'e164_key' => $row['e164_key'],
                'sip_prefix' => $row['sip_prefix'] ?? null,
                'tenant_shortuid' => $tenant,
                'status' => $row['status'],
                'sbc_dispatcher_setid' => $row['sbc_dispatcher_setid'] !== null
                    ? (int) $row['sbc_dispatcher_setid']
                    : null,
            ];
        }

        $ensure = $filter !== null ? array_keys($filter) : [];

        try {
            $result = $sbc->projectDids($payload, $dryRun, $ensure);

            return array_merge(['ok' => (bool) ($result['ok'] ?? false)], $result);
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'error' => $e->getMessage(),
                'upserted' => [],
                'removed' => [],
                'errors' => [$e->getMessage()],
            ];
        }
    }

    /**
     * Ensure tenant domain exists on SBC at current catalog setid.
     *
     * @return array<string, mixed>
     */
    public function registerTenantDomain(SbcFleetClient $sbc, string $shortuid): array
    {
        $meta = $this->registrar->getTenantMeta($shortuid);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }
        $fqdn = strtolower(trim((string) ($meta['fqdn'] ?? '')));
        if ($fqdn === '') {
            throw new \InvalidArgumentException('Tenant meta missing fqdn', 422);
        }
        $instanceId = (string) ($meta['instance_id'] ?? '');
        $catalog = $this->registrar->getCatalog();
        $setid = null;
        foreach ($catalog['instances'] ?? [] as $row) {
            if (is_array($row) && (string) ($row['id'] ?? '') === $instanceId) {
                $setid = isset($row['sbc_dispatcher_setid']) ? (int) $row['sbc_dispatcher_setid'] : null;
                break;
            }
        }
        if ($setid === null || $setid < 1) {
            throw new \InvalidArgumentException(
                "Instance {$instanceId} has no sbc_dispatcher_setid in catalog",
                422
            );
        }

        return $sbc->registerDomain($fqdn, $setid);
    }

    /**
     * Pure helper — apply one DID onto a tenant inventory list (unit-tested).
     *
     * @param  list<array<string, mixed>>  $dids
     * @param  array<string, mixed>  $record
     * @return list<array<string, mixed>>
     */
    public static function upsertDidRow(array $dids, array $record): array
    {
        $key = self::e164Key((string) ($record['e164'] ?? ''));
        $out = [];
        $found = false;
        foreach ($dids as $did) {
            if (! is_array($did)) {
                continue;
            }
            if (self::e164Key((string) ($did['e164'] ?? '')) === $key) {
                $out[] = array_merge($did, $record);
                $found = true;
            } else {
                $out[] = $did;
            }
        }
        if (! $found) {
            $out[] = $record;
        }

        return array_values($out);
    }

    public static function normalizeE164(string $raw): string
    {
        $s = trim($raw);
        if ($s === '') {
            throw new \InvalidArgumentException('e164 required', 422);
        }
        if ($s[0] !== '+') {
            $s = '+'.$s;
        }
        if (! preg_match('/^\+[1-9]\d{1,14}$/', $s)) {
            throw new \InvalidArgumentException('e164 must be E.164 with leading + (e.g. +442071234567)', 422);
        }

        return $s;
    }

    public static function e164Key(string $e164): string
    {
        return ltrim(trim($e164), '+');
    }

    /**
     * @return array{tenant_shortuid: string, status: string, assigned_at?: string}|null
     */
    private function findOwner(string $e164): ?array
    {
        $key = self::e164Key($e164);
        foreach ($this->registrar->listTenants() as $meta) {
            $shortuid = (string) ($meta['shortuid'] ?? '');
            if ($shortuid === '') {
                continue;
            }
            $inventory = $this->registrar->getDidInventory($shortuid);
            foreach ($inventory['dids'] ?? [] as $did) {
                if (! is_array($did)) {
                    continue;
                }
                if (self::e164Key((string) ($did['e164'] ?? '')) === $key) {
                    return [
                        'tenant_shortuid' => $shortuid,
                        'status' => (string) ($did['status'] ?? ''),
                        'assigned_at' => isset($did['assigned_at']) ? (string) $did['assigned_at'] : null,
                    ];
                }
            }
        }

        return null;
    }

    /** @param array<string, mixed> $record */
    private function upsertDidOnTenant(string $shortuid, array $record): array
    {
        $inventory = $this->registrar->getDidInventory($shortuid);
        $now = $this->registrar->nowIso();
        $inventory['tenant_shortuid'] = $shortuid;
        $inventory['updated_at'] = $now;
        $inventory['dids'] = self::upsertDidRow($inventory['dids'] ?? [], $record);
        $this->registrar->putDidInventory($shortuid, $inventory);

        return $inventory;
    }

    private function removeDidFromTenant(string $shortuid, string $e164): void
    {
        $inventory = $this->registrar->getDidInventory($shortuid);
        $key = self::e164Key($e164);
        $dids = [];
        foreach ($inventory['dids'] ?? [] as $did) {
            if (! is_array($did)) {
                continue;
            }
            if (self::e164Key((string) ($did['e164'] ?? '')) !== $key) {
                $dids[] = $did;
            }
        }
        $inventory['dids'] = array_values($dids);
        $inventory['updated_at'] = $this->registrar->nowIso();
        $inventory['tenant_shortuid'] = $shortuid;
        $this->registrar->putDidInventory($shortuid, $inventory);
    }

    /**
     * @return array{updated_at: string, entries: list<array<string, mixed>>}
     */
    private function compileAndWriteIndex(): array
    {
        $list = $this->listAll();
        $entries = [];
        foreach ($list['dids'] as $row) {
            if (! in_array((string) ($row['status'] ?? ''), self::OWNING_STATUSES, true)) {
                continue;
            }
            $entries[] = [
                'e164' => $row['e164'],
                'e164_key' => $row['e164_key'],
                'tenant_shortuid' => $row['tenant_shortuid'],
                'instance_id' => $row['instance_id'] ?: '',
                'sbc_dispatcher_setid' => $row['sbc_dispatcher_setid'],
                'status' => $row['status'],
            ];
        }
        $index = [
            'updated_at' => $this->registrar->nowIso(),
            'entries' => $entries,
        ];
        $this->registrar->putDidIndex($index);

        return $index;
    }
}
