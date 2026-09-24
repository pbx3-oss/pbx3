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
                    'delivery' => self::deliveryKind($did),
                    'match_prefix' => self::matchPrefix($did),
                    'tenant_shortuid' => $shortuid,
                    'tenant_label' => (string) ($meta['pkey'] ?? $meta['label'] ?? $shortuid),
                    'tenant_fqdn' => (string) ($meta['fqdn'] ?? ''),
                    'instance_id' => $instanceId,
                    'instance_label' => (string) ($instance['label'] ?? $instance['fqdn'] ?? $instanceId),
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

        $delivery = strtolower(trim((string) ($body['delivery'] ?? 'singleton')));
        if (! in_array($delivery, ['singleton', 'block'], true)) {
            throw new \InvalidArgumentException('delivery must be singleton or block', 422);
        }

        $e164Digits = self::e164Key($e164);
        $sipPrefix = null;
        if (isset($body['sip_prefix']) && is_string($body['sip_prefix']) && trim($body['sip_prefix']) !== '') {
            $sipPrefix = preg_replace('/\D+/', '', trim($body['sip_prefix'])) ?? '';
            if ($sipPrefix === '') {
                throw new \InvalidArgumentException('sip_prefix must be digits', 422);
            }
        }
        if ($delivery === 'block') {
            if ($sipPrefix === null || $sipPrefix === '') {
                throw new \InvalidArgumentException(
                    'block delivery requires sip_prefix (OpenSIPS match digits after dialect normalize, '
                    .'e.g. 4419249264 — not UK national 0… face)',
                    422
                );
            }
            if (strlen($sipPrefix) >= strlen($e164Digits)) {
                throw new \InvalidArgumentException(
                    'block sip_prefix must be shorter than the E.164 digits (block vs singleton)',
                    422
                );
            }
            self::assertHop1PrefixNotNationalAlias($sipPrefix, $e164Digits);
        } else {
            // singleton: hop-1 always matches digit E.164 after DIALECT_INBOUND_NORMALIZE.
            // Omit sip_prefix (or send e164 digits). Never keep a stale national face across reassign.
            if ($sipPrefix !== null && $sipPrefix !== '' && $sipPrefix !== $e164Digits) {
                self::assertHop1PrefixNotNationalAlias($sipPrefix, $e164Digits);
                throw new \InvalidArgumentException(
                    'singleton hop-1 must omit sip_prefix (or set it to digit E.164 '
                    .$e164Digits.'). Use delivery=block for a shorter match prefix.',
                    422
                );
            }
            $sipPrefix = null;
        }

        if ($sipPrefix !== null) {
            $prefixOwner = $this->findOwnerByMatchPrefix($sipPrefix);
            if ($prefixOwner !== null
                && self::e164Key((string) ($prefixOwner['e164'] ?? '')) !== self::e164Key($e164)
                && in_array($prefixOwner['status'], self::OWNING_STATUSES, true)
                && ! $reassign
            ) {
                throw new \RuntimeException(
                    "Match prefix {$sipPrefix} already owned by tenant {$prefixOwner['tenant_shortuid']} "
                    ."({$prefixOwner['e164']}) — pass reassign: true",
                    409
                );
            }
            if ($prefixOwner !== null
                && self::e164Key((string) ($prefixOwner['e164'] ?? '')) !== self::e164Key($e164)
                && $reassign
                && in_array($prefixOwner['status'], self::OWNING_STATUSES, true)
            ) {
                $this->removeDidFromTenant(
                    (string) $prefixOwner['tenant_shortuid'],
                    (string) $prefixOwner['e164']
                );
            }
        }

        $now = $this->registrar->nowIso();
        $record = [
            'e164' => $e164,
            'status' => $status,
            'delivery' => $delivery,
            'updated_at' => $now,
        ];
        foreach (['carrier', 'label', 'notes'] as $opt) {
            if (isset($body[$opt]) && is_string($body[$opt]) && trim($body[$opt]) !== '') {
                $record[$opt] = trim($body[$opt]);
            }
        }
        if ($delivery === 'block' && $sipPrefix !== null) {
            $record['sip_prefix'] = $sipPrefix;
        } else {
            // Explicit null → upsertDidRow drops a prior sip_prefix (array_merge would keep it).
            $record['sip_prefix'] = null;
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

        return $sbc->registerDomain(
            $fqdn,
            $setid,
            trim((string) ($meta['pkey'] ?? $meta['label'] ?? '')) ?: null,
            $shortuid !== '' ? $shortuid : null
        );
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
        $clearSipPrefix = array_key_exists('sip_prefix', $record) && $record['sip_prefix'] === null;
        $out = [];
        $found = false;
        foreach ($dids as $did) {
            if (! is_array($did)) {
                continue;
            }
            if (self::e164Key((string) ($did['e164'] ?? '')) === $key) {
                $merged = array_merge($did, $record);
                if ($clearSipPrefix) {
                    unset($merged['sip_prefix']);
                }
                $out[] = $merged;
                $found = true;
            } else {
                $out[] = $did;
            }
        }
        if (! $found) {
            $row = $record;
            if ($clearSipPrefix) {
                unset($row['sip_prefix']);
            }
            $out[] = $row;
        }

        return array_values($out);
    }

    /**
     * UK national 0… → digit E.164 after OpenSIPS DIALECT_INBOUND_NORMALIZE (0 + NSN → 44 + NSN).
     */
    public static function ukNationalZeroToE164Digits(string $prefix): ?string
    {
        $prefix = preg_replace('/\D+/', '', $prefix) ?? '';
        if ($prefix === '' || $prefix[0] !== '0' || strlen($prefix) < 2) {
            return null;
        }

        return '44'.substr($prefix, 1);
    }

    /**
     * Reject hop-1 prefixes that are UK national 0… face (miss after OpenSIPS DIALECT_INBOUND_NORMALIZE).
     */
    public static function assertHop1PrefixNotNationalAlias(string $prefix, string $e164Digits): void
    {
        $prefix = preg_replace('/\D+/', '', $prefix) ?? '';
        if ($prefix === '' || $prefix[0] !== '0') {
            return;
        }
        $hint = self::ukNationalZeroToE164Digits($prefix) ?? ('44'.substr($prefix, 1));
        $sameDid = ($hint === $e164Digits);
        throw new \InvalidArgumentException(
            "sip_prefix {$prefix} is UK national (leading 0). "
            .'OpenSIPS normalizes 0… → 44… before drouting — use digit E.164'
            .($sameDid ? " (omit sip_prefix for singleton → {$e164Digits})" : " form {$hint}")
            .'.',
            422
        );
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
     * @return array{tenant_shortuid: string, status: string, e164: string, assigned_at?: string}|null
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
                        'e164' => (string) ($did['e164'] ?? ''),
                        'status' => (string) ($did['status'] ?? ''),
                        'assigned_at' => isset($did['assigned_at']) ? (string) $did['assigned_at'] : null,
                    ];
                }
            }
        }

        return null;
    }

    /**
     * Owning DID that projects to this OpenSIPS match prefix (sip_prefix or e164 digits).
     *
     * @return array{tenant_shortuid: string, status: string, e164: string}|null
     */
    private function findOwnerByMatchPrefix(string $prefix): ?array
    {
        $prefix = preg_replace('/\D+/', '', $prefix) ?? '';
        if ($prefix === '') {
            return null;
        }
        foreach ($this->listAll()['dids'] as $row) {
            if (! in_array((string) ($row['status'] ?? ''), self::OWNING_STATUSES, true)) {
                continue;
            }
            if ((string) ($row['match_prefix'] ?? '') === $prefix) {
                return [
                    'tenant_shortuid' => (string) $row['tenant_shortuid'],
                    'e164' => (string) $row['e164'],
                    'status' => (string) $row['status'],
                ];
            }
        }

        return null;
    }

    /**
     * @param  array<string, mixed>  $did
     */
    public static function matchPrefix(array $did): string
    {
        if (isset($did['sip_prefix']) && is_string($did['sip_prefix']) && trim($did['sip_prefix']) !== '') {
            return preg_replace('/\D+/', '', $did['sip_prefix']) ?? '';
        }

        return self::e164Key((string) ($did['e164'] ?? ''));
    }

    /**
     * @param  array<string, mixed>  $did
     */
    public static function deliveryKind(array $did): string
    {
        $explicit = strtolower(trim((string) ($did['delivery'] ?? '')));
        if ($explicit === 'block' || $explicit === 'singleton') {
            return $explicit;
        }
        $prefix = self::matchPrefix($did);
        $e164Digits = self::e164Key((string) ($did['e164'] ?? ''));
        if ($prefix !== '' && $e164Digits !== '' && strlen($prefix) < strlen($e164Digits)) {
            return 'block';
        }

        return 'singleton';
    }

    /**
     * Catalog (HoR) ↔ SBC fleet=did inbound rules (Rule 13).
     *
     * @return array<string, mixed>
     */
    public function reconcile(SbcFleetClient $sbc): array
    {
        $list = $this->listAll();
        $live = $sbc->listDidRules();

        return self::compareDidProjection($list['dids'], $live);
    }

    /**
     * Pure compare — unit-tested.
     *
     * @param  list<array<string, mixed>>  $catalogDids  flat listAll rows
     * @param  list<array<string, mixed>>  $sbcRules
     * @return array<string, mixed>
     */
    public static function compareDidProjection(array $catalogDids, array $sbcRules): array
    {
        $expected = [];
        foreach ($catalogDids as $row) {
            if (! is_array($row)) {
                continue;
            }
            $status = (string) ($row['status'] ?? '');
            if (! in_array($status, ['active', 'porting'], true)) {
                continue;
            }
            $prefix = (string) ($row['match_prefix'] ?? self::matchPrefix($row));
            if ($prefix === '') {
                continue;
            }
            $expected[$prefix] = [
                'prefix' => $prefix,
                'e164' => (string) ($row['e164'] ?? ''),
                'tenant_shortuid' => (string) ($row['tenant_shortuid'] ?? ''),
                'expected_setid' => isset($row['sbc_dispatcher_setid']) && $row['sbc_dispatcher_setid'] !== null
                    ? (int) $row['sbc_dispatcher_setid']
                    : null,
                'delivery' => (string) ($row['delivery'] ?? self::deliveryKind($row)),
            ];
        }

        $actual = [];
        foreach ($sbcRules as $row) {
            if (! is_array($row)) {
                continue;
            }
            $prefix = (string) ($row['prefix'] ?? '');
            $actual[$prefix] = [
                'prefix' => $prefix,
                'tenant_shortuid' => (string) ($row['tenant_shortuid'] ?? ''),
                'e164_key' => (string) ($row['e164_key'] ?? ''),
                'actual_setid' => isset($row['setid']) && $row['setid'] !== null ? (int) $row['setid'] : null,
                'ruleid' => (int) ($row['ruleid'] ?? 0),
            ];
        }

        $drifts = [];
        foreach ($expected as $prefix => $exp) {
            if (! isset($actual[$prefix])) {
                $drifts[] = [
                    'severity' => 'error',
                    'kind' => 'missing_on_sbc',
                    'prefix' => $prefix,
                    'e164' => $exp['e164'],
                    'tenant_shortuid' => $exp['tenant_shortuid'],
                    'expected_setid' => $exp['expected_setid'],
                    'actual_setid' => null,
                    'detail' => 'Catalog active/porting — no fleet=did rule on SBC',
                ];
                continue;
            }
            $act = $actual[$prefix];
            if ($act['tenant_shortuid'] !== '' && $act['tenant_shortuid'] !== $exp['tenant_shortuid']) {
                $drifts[] = [
                    'severity' => 'error',
                    'kind' => 'tenant_mismatch',
                    'prefix' => $prefix,
                    'e164' => $exp['e164'],
                    'tenant_shortuid' => $exp['tenant_shortuid'],
                    'expected_setid' => $exp['expected_setid'],
                    'actual_setid' => $act['actual_setid'],
                    'detail' => "SBC attrs tenant={$act['tenant_shortuid']} ≠ catalog {$exp['tenant_shortuid']}",
                ];
            }
            if ($exp['expected_setid'] !== null
                && $act['actual_setid'] !== null
                && (int) $exp['expected_setid'] !== (int) $act['actual_setid']
            ) {
                $drifts[] = [
                    'severity' => 'error',
                    'kind' => 'setid_mismatch',
                    'prefix' => $prefix,
                    'e164' => $exp['e164'],
                    'tenant_shortuid' => $exp['tenant_shortuid'],
                    'expected_setid' => $exp['expected_setid'],
                    'actual_setid' => $act['actual_setid'],
                    'detail' => 'SBC rule gwlist resolves to different dispatcher setid than catalog',
                ];
            }
            if ($exp['expected_setid'] !== null && $act['actual_setid'] === null) {
                $drifts[] = [
                    'severity' => 'warning',
                    'kind' => 'setid_unresolved',
                    'prefix' => $prefix,
                    'e164' => $exp['e164'],
                    'tenant_shortuid' => $exp['tenant_shortuid'],
                    'expected_setid' => $exp['expected_setid'],
                    'actual_setid' => null,
                    'detail' => 'Could not resolve setid from SBC gwlist/gwid',
                ];
            }
        }

        foreach ($actual as $prefix => $act) {
            if (isset($expected[$prefix])) {
                continue;
            }
            $drifts[] = [
                'severity' => 'warning',
                'kind' => 'orphan_on_sbc',
                'prefix' => $prefix,
                'e164' => $act['e164_key'] !== '' ? '+'.$act['e164_key'] : '',
                'tenant_shortuid' => $act['tenant_shortuid'],
                'expected_setid' => null,
                'actual_setid' => $act['actual_setid'],
                'detail' => 'fleet=did rule on SBC with no active/porting catalog row — Project may purge',
            ];
        }

        $errors = 0;
        $warnings = 0;
        foreach ($drifts as $d) {
            if (($d['severity'] ?? '') === 'error') {
                $errors++;
            } else {
                $warnings++;
            }
        }

        return [
            'ok' => $drifts === [],
            'checked_at' => gmdate('c'),
            'summary' => [
                'catalog_deliverable' => count($expected),
                'sbc_fleet_rules' => count($actual),
                'drifts' => count($drifts),
                'errors' => $errors,
                'warnings' => $warnings,
            ],
            'drifts' => $drifts,
        ];
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
