<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * C3 — catalog MAC index (provision routing HoR) + static nginx map projection.
 *
 * HoR: catalog/mac-index.json
 * Artifact: catalog/provision-mac.map (nginx map include; optional S3 seed)
 * Edge GET path uses local map only — no live gatekeeper / per-request S3 (#3).
 *
 * No secrets on the index. Conflict = reject until clear (§6).
 */
final class MacIndexStore
{
    public const INDEX_KEY = 'catalog/mac-index.json';

    public const MAP_KEY = 'catalog/provision-mac.map';

    public const PROVISION_PORT = 41363;

    public function __construct(
        private readonly MacIndexPersistence $registrar,
    ) {
    }

    /**
     * @return array{version: int, updated_at: string, entries: list<array<string, mixed>>}
     */
    public function getIndex(): array
    {
        return $this->registrar->getMacIndex();
    }

    /**
     * Claim (upsert) a MAC for tenant+instance. Rejects if another instance holds it.
     *
     * @param  array<string, mixed>  $body
     * @return array{mac: string, tenant_shortuid: string, instance_id: string, updated_at: string, created: bool}
     */
    public function claim(array $body): array
    {
        $mac = self::normalizeMac((string) ($body['mac'] ?? ''));
        $tenant = strtolower(trim((string) ($body['tenant_shortuid'] ?? '')));
        $instanceId = trim((string) ($body['instance_id'] ?? ''));

        if ($tenant === '' || ! preg_match('/^[a-z0-9]+$/', $tenant)) {
            throw new \InvalidArgumentException('tenant_shortuid required (lowercase alnum)', 422);
        }
        if ($instanceId === '') {
            throw new \InvalidArgumentException('instance_id required', 422);
        }

        $index = $this->getIndex();
        $now = $this->registrar->nowIso();
        $created = true;
        $entries = [];
        foreach ($index['entries'] ?? [] as $row) {
            if (! is_array($row)) {
                continue;
            }
            $rowMac = (string) ($row['mac'] ?? '');
            if ($rowMac === $mac) {
                $holder = trim((string) ($row['instance_id'] ?? ''));
                if ($holder !== '' && $holder !== $instanceId) {
                    throw new \RuntimeException(
                        "MAC {$mac} already claimed by instance {$holder}; clear before reclaim",
                        409
                    );
                }
                $created = false;
                $entries[] = [
                    'mac' => $mac,
                    'tenant_shortuid' => $tenant,
                    'instance_id' => $instanceId,
                    'updated_at' => $now,
                ];
                continue;
            }
            $entries[] = $row;
        }
        if ($created) {
            $entries[] = [
                'mac' => $mac,
                'tenant_shortuid' => $tenant,
                'instance_id' => $instanceId,
                'updated_at' => $now,
            ];
        }

        usort($entries, static fn (array $a, array $b): int => strcmp((string) $a['mac'], (string) $b['mac']));
        $index = [
            'version' => 1,
            'updated_at' => $now,
            'entries' => $entries,
        ];
        $this->persistIndexAndMap($index);

        return [
            'mac' => $mac,
            'tenant_shortuid' => $tenant,
            'instance_id' => $instanceId,
            'updated_at' => $now,
            'created' => $created,
        ];
    }

    /**
     * Delete MAC binding. Idempotent if absent.
     *
     * @param  array<string, mixed>  $body
     * @return array{mac: string, cleared: bool}
     */
    public function clear(array $body): array
    {
        $mac = self::normalizeMac((string) ($body['mac'] ?? ''));
        $index = $this->getIndex();
        $before = count($index['entries'] ?? []);
        $entries = [];
        foreach ($index['entries'] ?? [] as $row) {
            if (! is_array($row)) {
                continue;
            }
            if ((string) ($row['mac'] ?? '') === $mac) {
                continue;
            }
            $entries[] = $row;
        }
        $cleared = count($entries) < $before;
        if ($cleared) {
            $index = [
                'version' => 1,
                'updated_at' => $this->registrar->nowIso(),
                'entries' => $entries,
            ];
            $this->persistIndexAndMap($index);
        }

        return ['mac' => $mac, 'cleared' => $cleared];
    }

    /**
     * Tenant move: rewrite instance_id for all MAC rows of this tenant (with setid job).
     *
     * @return array{tenant_shortuid: string, instance_id: string, rewritten: int}
     */
    public function rewriteTenantInstance(string $tenantShortuid, string $destInstanceId): array
    {
        $tenant = strtolower(trim($tenantShortuid));
        $dest = trim($destInstanceId);
        if ($tenant === '' || ! preg_match('/^[a-z0-9]+$/', $tenant)) {
            throw new \InvalidArgumentException('tenant_shortuid required (lowercase alnum)', 422);
        }
        if ($dest === '') {
            throw new \InvalidArgumentException('instance_id required', 422);
        }

        $index = $this->getIndex();
        $now = $this->registrar->nowIso();
        $rewritten = 0;
        $entries = [];
        foreach ($index['entries'] ?? [] as $row) {
            if (! is_array($row)) {
                continue;
            }
            if ((string) ($row['tenant_shortuid'] ?? '') === $tenant) {
                $row['instance_id'] = $dest;
                $row['updated_at'] = $now;
                $rewritten++;
            }
            $entries[] = $row;
        }

        if ($rewritten > 0) {
            $index = [
                'version' => 1,
                'updated_at' => $now,
                'entries' => $entries,
            ];
            $this->persistIndexAndMap($index);
        }

        return [
            'tenant_shortuid' => $tenant,
            'instance_id' => $dest,
            'rewritten' => $rewritten,
        ];
    }

    /**
     * Rebuild map artifact from current index + catalog instances (no index mutation).
     *
     * @return array{updated_at: string, entries: int, map_bytes: int}
     */
    public function projectMap(): array
    {
        $index = $this->getIndex();
        $map = self::buildNginxMap($index, $this->instanceLookup());
        self::assertMapHasNoSecrets($map);
        $this->registrar->putProvisionMacMap($map);

        return [
            'updated_at' => (string) ($index['updated_at'] ?? $this->registrar->nowIso()),
            'entries' => count($index['entries'] ?? []),
            'map_bytes' => strlen($map),
        ];
    }

    /**
     * C8 — compare MAC index (HoR) to provision-mac.map body.
     *
     * @param  array{version?: int, updated_at?: string, entries?: list<array<string, mixed>>}  $index
     * @param  array<string, array<string, mixed>>  $instancesById
     * @return array{
     *   ok: bool,
     *   summary: array{matched: int, drifts: int},
     *   drifts: list<array<string, mixed>>,
     *   matched: list<array<string, mixed>>
     * }
     */
    public static function compareIndexToMap(array $index, string $mapBody, array $instancesById): array
    {
        $expected = [];
        foreach ($index['entries'] ?? [] as $row) {
            if (! is_array($row)) {
                continue;
            }
            $mac = (string) ($row['mac'] ?? '');
            $instanceId = (string) ($row['instance_id'] ?? '');
            if ($mac === '' || $instanceId === '') {
                continue;
            }
            $upstream = self::homeProvisionBaseUrl($instancesById[$instanceId] ?? []);
            if ($upstream === null) {
                continue;
            }
            $expected[$mac] = $upstream;
        }

        $actual = self::parseNginxMapUpstreams($mapBody);

        $drifts = [];
        $matched = [];

        try {
            self::assertMapHasNoSecrets($mapBody);
        } catch (\RuntimeException $e) {
            $drifts[] = [
                'kind' => 'map_secret_leak',
                'severity' => 'error',
                'detail' => $e->getMessage(),
            ];
        }

        foreach ($expected as $mac => $upstream) {
            if (! isset($actual[$mac])) {
                $drifts[] = [
                    'kind' => 'map_missing_mac',
                    'severity' => 'error',
                    'mac' => $mac,
                    'expected_upstream' => $upstream,
                ];
                continue;
            }
            if ($actual[$mac] !== $upstream) {
                $drifts[] = [
                    'kind' => 'map_upstream_mismatch',
                    'severity' => 'error',
                    'mac' => $mac,
                    'expected_upstream' => $upstream,
                    'actual_upstream' => $actual[$mac],
                ];
                continue;
            }
            $matched[] = [
                'mac' => $mac,
                'upstream' => $upstream,
            ];
        }

        foreach ($actual as $mac => $upstream) {
            if (! isset($expected[$mac])) {
                $drifts[] = [
                    'kind' => 'map_extra_mac',
                    'severity' => 'warning',
                    'mac' => $mac,
                    'actual_upstream' => $upstream,
                ];
            }
        }

        return [
            'ok' => $drifts === [],
            'summary' => [
                'matched' => count($matched),
                'drifts' => count($drifts),
            ],
            'drifts' => $drifts,
            'matched' => $matched,
        ];
    }

    /**
     * @return array<string, string> mac => upstream URL
     */
    public static function parseNginxMapUpstreams(string $mapBody): array
    {
        $out = [];
        if (preg_match_all('/~\*\^([0-9a-fA-F]{12})\$\s+"([^"]+)";/', $mapBody, $m, PREG_SET_ORDER) === false) {
            return $out;
        }
        foreach ($m as $row) {
            $out[strtolower($row[1])] = $row[2];
        }

        return $out;
    }

    /**
     * Live reconcile: index HoR vs current map artifact.
     *
     * @return array{
     *   ok: bool,
     *   summary: array{matched: int, drifts: int},
     *   drifts: list<array<string, mixed>>,
     *   matched: list<array<string, mixed>>
     * }
     */
    public function reconcileMap(): array
    {
        return self::compareIndexToMap(
            $this->getIndex(),
            $this->registrar->getProvisionMacMap(),
            $this->instanceLookup()
        );
    }

    /**
     * @param  array{version?: int, updated_at?: string, entries?: list<array<string, mixed>>}  $index
     * @param  array<string, array<string, mixed>>  $instancesById
     */
    public static function buildNginxMap(array $index, array $instancesById): string
    {
        $lines = [
            '# PBX3 provision MAC map — generated; do not hand-edit',
            '# Include from provision vhost; GET path must not call gatekeeper (#3)',
            'map $provision_mac $provision_upstream {',
            '    default "";',
        ];
        foreach ($index['entries'] ?? [] as $row) {
            if (! is_array($row)) {
                continue;
            }
            $mac = (string) ($row['mac'] ?? '');
            $instanceId = (string) ($row['instance_id'] ?? '');
            if ($mac === '' || $instanceId === '') {
                continue;
            }
            $upstream = self::homeProvisionBaseUrl($instancesById[$instanceId] ?? []);
            if ($upstream === null) {
                continue;
            }
            // Case-insensitive regex key — nginx map string keys collide on case (#3, no lua)
            $lines[] = '    ~*^'.$mac.'$ "'.$upstream.'";';
        }
        $lines[] = '}';
        $lines[] = '';

        return implode("\n", $lines);
    }

    /**
     * @param  array<string, mixed>  $instance
     */
    public static function homeProvisionBaseUrl(array $instance): ?string
    {
        $host = self::homeHostFromInstance($instance);
        if ($host === null || $host === '') {
            return null;
        }

        return 'http://'.$host.':'.self::PROVISION_PORT;
    }

    /**
     * Prefer SIP backend host (SBC→home path); else instance fqdn.
     *
     * @param  array<string, mixed>  $instance
     */
    public static function homeHostFromInstance(array $instance): ?string
    {
        $uri = isset($instance['sbc_backend_uri']) ? trim((string) $instance['sbc_backend_uri']) : '';
        if ($uri !== '' && preg_match('#^sip:([^:;]+)#i', $uri, $m)) {
            $host = trim($m[1], '[]');
            if ($host !== '') {
                return strtolower($host);
            }
        }
        $fqdn = isset($instance['fqdn']) ? strtolower(trim((string) $instance['fqdn'])) : '';

        return $fqdn !== '' ? $fqdn : null;
    }

    public static function normalizeMac(string $raw): string
    {
        $hex = strtolower(preg_replace('/[^0-9a-fA-F]/', '', $raw) ?? '');
        if (strlen($hex) !== 12 || $hex === '000000000000') {
            throw new \InvalidArgumentException('mac must be 12 hex characters (non-zero)', 422);
        }

        return $hex;
    }

    /**
     * Assert map artifact has no secret-like substrings (C7 / fail-closed).
     */
    public static function assertMapHasNoSecrets(string $map): void
    {
        $forbidden = ['password', 'sip_auth', 'admin_pass', '\$password', 'secret'];
        $lower = strtolower($map);
        foreach ($forbidden as $needle) {
            if (str_contains($lower, strtolower($needle))) {
                throw new \RuntimeException('provision map artifact must not contain secrets', 500);
            }
        }
    }

    /**
     * @param  array{version: int, updated_at: string, entries: list<array<string, mixed>>}  $index
     */
    private function persistIndexAndMap(array $index): void
    {
        $this->registrar->putMacIndex($index);
        $map = self::buildNginxMap($index, $this->instanceLookup());
        self::assertMapHasNoSecrets($map);
        $this->registrar->putProvisionMacMap($map);
    }

    /** @return array<string, array<string, mixed>> */
    private function instanceLookup(): array
    {
        $catalog = $this->registrar->getCatalog();
        $byId = [];
        foreach ($catalog['instances'] ?? [] as $row) {
            if (is_array($row) && isset($row['id'])) {
                $byId[(string) $row['id']] = $row;
            }
        }

        return $byId;
    }
}
