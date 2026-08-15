<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * S10.4 — catalog (HoR) ↔ SBC domain.setid reconcile.
 * Direction: catalog expected; SBC is projection (Rule 13).
 * Force-project fixes setid_mismatch via repointTenant and missing_fleet_tag via registerDomain.
 * Soft-decommissioned tenants (Fleet Delete audit metas) are omitted — SBC domain removal is expected.
 * missing_on_sbc / DID → S10.5.
 */
final class CatalogReconcile
{
    public function __construct(
        private readonly S3Registrar $registrar,
        private readonly SbcFleetClient $sbc,
    ) {}

    /** @return array<string, mixed> */
    public function report(): array
    {
        return self::compare(
            $this->registrar->getCatalog(),
            $this->registrar->listTenants(),
            $this->sbc->listDomains()
        );
    }

    /**
     * Project catalog expected setids onto SBC for setid_mismatch drifts;
     * stamp fleet=domain for missing_fleet_tag.
     *
     * Body:
     * - confirm (bool) required unless dry_run
     * - dry_run (bool) optional — plan only, no SBC writes
     * - domains (string[]) optional — limit to these domain names
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function project(array $body): array
    {
        $dryRun = ! empty($body['dry_run']);
        if (! $dryRun && empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to project (or dry_run: true)', 422);
        }

        $domainFilter = null;
        if (isset($body['domains']) && is_array($body['domains'])) {
            $domainFilter = [];
            foreach ($body['domains'] as $d) {
                if (! is_string($d)) {
                    continue;
                }
                $key = strtolower(trim($d));
                if ($key !== '') {
                    $domainFilter[$key] = true;
                }
            }
            if ($domainFilter === []) {
                $domainFilter = null;
            }
        }

        $before = $this->report();
        $plan = self::planProject($before, $domainFilter);

        if ($dryRun) {
            return [
                'dry_run' => true,
                'actions' => $plan['actions'],
                'skipped' => $plan['skipped'],
                'before' => $before,
            ];
        }

        $projected = [];
        foreach ($plan['actions'] as $action) {
            $domain = (string) $action['domain'];
            $kind = (string) ($action['kind'] ?? '');
            $to = (int) $action['to_setid'];
            try {
                $live = [];
                foreach ($this->sbc->listDispatcherSets() as $row) {
                    $live[] = (int) $row['setid'];
                }
                SbcSetidGuard::assertLive($to, $live);
                if ($kind === 'missing_fleet_tag') {
                    $sbcResult = $this->sbc->registerDomain($domain, $to);
                    $projected[] = [
                        ...$action,
                        'ok' => true,
                        'stamped' => true,
                        'dest_setid' => $sbcResult['setid'] ?? $to,
                    ];
                } else {
                    $sbcResult = $this->sbc->repointTenant($domain, $to);
                    $projected[] = [
                        ...$action,
                        'ok' => true,
                        'previous_setid' => $sbcResult['previous_setid'] ?? $action['from_setid'],
                        'dest_setid' => $sbcResult['dest_setid'] ?? $to,
                    ];
                }
            } catch (\Throwable $e) {
                $projected[] = [
                    ...$action,
                    'ok' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        $after = $this->report();

        return [
            'dry_run' => false,
            'projected' => $projected,
            'skipped' => $plan['skipped'],
            'before' => [
                'ok' => $before['ok'],
                'summary' => $before['summary'],
                'checked_at' => $before['checked_at'],
            ],
            'after' => $after,
        ];
    }

    /**
     * Build project actions from a reconcile report (pure / unit-tested).
     *
     * @param  array<string, mixed>  $report
     * @param  array<string, true>|null  $domainFilter  lowercase domain keys
     * @return array{actions: list<array<string, mixed>>, skipped: list<array<string, mixed>>}
     */
    public static function planProject(array $report, ?array $domainFilter = null): array
    {
        $actions = [];
        $skipped = [];
        foreach ($report['drifts'] ?? [] as $drift) {
            if (! is_array($drift)) {
                continue;
            }
            $kind = (string) ($drift['kind'] ?? '');
            $domain = trim((string) ($drift['domain'] ?? ''));
            $domainKey = strtolower($domain);

            if ($domainFilter !== null && ($domain === '' || ! isset($domainFilter[$domainKey]))) {
                continue;
            }

            if ($kind === 'setid_mismatch' || $kind === 'missing_fleet_tag') {
                $to = $drift['expected_setid'] ?? null;
                if (! is_int($to) && ! (is_string($to) && ctype_digit($to))) {
                    $skipped[] = [
                        'kind' => $kind,
                        'domain' => $domain !== '' ? $domain : null,
                        'shortuid' => $drift['shortuid'] ?? null,
                        'reason' => 'missing expected_setid',
                    ];
                    continue;
                }
                $to = (int) $to;
                if ($to < 1) {
                    $skipped[] = [
                        'kind' => $kind,
                        'domain' => $domain,
                        'shortuid' => $drift['shortuid'] ?? null,
                        'reason' => 'invalid expected_setid',
                    ];
                    continue;
                }
                $actions[] = [
                    'kind' => $kind,
                    'shortuid' => $drift['shortuid'] ?? null,
                    'domain' => $domain,
                    'instance_id' => $drift['instance_id'] ?? null,
                    'from_setid' => isset($drift['actual_setid']) ? (int) $drift['actual_setid'] : null,
                    'to_setid' => $to,
                ];
                continue;
            }

            $reason = match ($kind) {
                'missing_on_sbc' => 'domain row missing — register tenant domain is S10.5',
                'orphan_on_sbc' => 'orphan not authored in catalog — not projected (Rule 13)',
                'unresolvable_expected_setid' => 'catalog has no resolvable sbc_dispatcher_setid',
                'tenant_missing_domain' => 'tenant has no fqdn / sbc_domain',
                default => 'not projectable in S10.4',
            };
            $skipped[] = [
                'kind' => $kind !== '' ? $kind : 'unknown',
                'domain' => $domain !== '' ? $domain : null,
                'shortuid' => $drift['shortuid'] ?? null,
                'reason' => $reason,
            ];
        }

        return ['actions' => $actions, 'skipped' => $skipped];
    }

    /**
     * Pure compare for unit tests (no S3 / HTTP).
     *
     * @param  array<string, mixed>  $catalog
     * @param  list<array<string, mixed>>  $tenants
     * @param  list<array{domain: string, setid: int, fleet_owned?: bool}>  $sbcDomains
     * @return array<string, mixed>
     */
    public static function compare(array $catalog, array $tenants, array $sbcDomains): array
    {
        $instancesById = [];
        foreach ($catalog['instances'] ?? [] as $inst) {
            if (! is_array($inst)) {
                continue;
            }
            $id = (string) ($inst['id'] ?? '');
            if ($id !== '') {
                $instancesById[$id] = $inst;
            }
        }

        $instanceFqdns = [];
        foreach ($instancesById as $inst) {
            $fqdn = strtolower(trim((string) ($inst['fqdn'] ?? '')));
            if ($fqdn !== '') {
                $instanceFqdns[$fqdn] = true;
            }
        }

        $sbcByDomain = [];
        foreach ($sbcDomains as $row) {
            $domain = strtolower(trim((string) ($row['domain'] ?? '')));
            if ($domain === '') {
                continue;
            }
            // Absent fleet_owned (older SBC) → treat as tagged to avoid false drift until tip-deploy.
            $fleetOwned = array_key_exists('fleet_owned', $row)
                ? (bool) $row['fleet_owned']
                : true;
            $sbcByDomain[$domain] = [
                'setid' => (int) ($row['setid'] ?? 0),
                'fleet_owned' => $fleetOwned,
            ];
        }

        $drifts = [];
        $matched = 0;
        $tenantDomains = [];
        $considered = 0;

        foreach ($tenants as $tenant) {
            if (! is_array($tenant)) {
                continue;
            }
            // Fleet Delete soft-decommissions meta for audit; domain gone on SBC is correct.
            if (strtolower((string) ($tenant['status'] ?? 'active')) === 'decommissioned') {
                continue;
            }
            $considered++;
            $shortuid = (string) ($tenant['shortuid'] ?? '');
            $domain = self::tenantDomain($tenant);
            if ($domain === '') {
                $drifts[] = [
                    'kind' => 'tenant_missing_domain',
                    'severity' => 'error',
                    'shortuid' => $shortuid !== '' ? $shortuid : null,
                    'detail' => 'Tenant meta has no fqdn / sbc_domain',
                ];
                continue;
            }

            $domainKey = strtolower($domain);
            $tenantDomains[$domainKey] = true;
            $instanceId = (string) ($tenant['instance_id'] ?? '');
            $expectedSetid = self::expectedSetid($instanceId, $instancesById);

            if (! array_key_exists($domainKey, $sbcByDomain)) {
                $drifts[] = [
                    'kind' => 'missing_on_sbc',
                    'severity' => 'error',
                    'shortuid' => $shortuid !== '' ? $shortuid : null,
                    'domain' => $domain,
                    'instance_id' => $instanceId !== '' ? $instanceId : null,
                    'expected_setid' => $expectedSetid,
                    'actual_setid' => null,
                    'detail' => "No SBC domain row for {$domain}",
                ];
                continue;
            }

            $actualSetid = $sbcByDomain[$domainKey]['setid'];
            $fleetOwned = $sbcByDomain[$domainKey]['fleet_owned'];

            if ($expectedSetid === null) {
                $drifts[] = [
                    'kind' => 'unresolvable_expected_setid',
                    'severity' => 'warning',
                    'shortuid' => $shortuid !== '' ? $shortuid : null,
                    'domain' => $domain,
                    'instance_id' => $instanceId !== '' ? $instanceId : null,
                    'expected_setid' => null,
                    'actual_setid' => $actualSetid,
                    'detail' => $instanceId === ''
                        ? 'Tenant has no instance_id — cannot derive expected setid'
                        : (isset($instancesById[$instanceId])
                            ? "Instance {$instanceId} has no sbc_dispatcher_setid"
                            : "Unknown instance_id {$instanceId} in catalog"),
                ];
                continue;
            }

            if ($actualSetid !== $expectedSetid) {
                $drifts[] = [
                    'kind' => 'setid_mismatch',
                    'severity' => 'error',
                    'shortuid' => $shortuid !== '' ? $shortuid : null,
                    'domain' => $domain,
                    'instance_id' => $instanceId,
                    'expected_setid' => $expectedSetid,
                    'actual_setid' => $actualSetid,
                    'detail' => "Catalog expects setid {$expectedSetid}; SBC has {$actualSetid}",
                ];
                continue;
            }

            if (! $fleetOwned) {
                $drifts[] = [
                    'kind' => 'missing_fleet_tag',
                    'severity' => 'warning',
                    'shortuid' => $shortuid !== '' ? $shortuid : null,
                    'domain' => $domain,
                    'instance_id' => $instanceId !== '' ? $instanceId : null,
                    'expected_setid' => $expectedSetid,
                    'actual_setid' => $actualSetid,
                    'detail' => "SBC domain {$domain} matches setid but lacks fleet=domain — Magrathea may co-author",
                ];
                continue;
            }

            $matched++;
        }

        foreach ($sbcByDomain as $domainKey => $row) {
            $setid = $row['setid'];
            if (isset($tenantDomains[$domainKey])) {
                continue;
            }
            if (isset($instanceFqdns[$domainKey])) {
                continue; // node/instance FQDN rows are expected; not tenant HoR
            }
            $drifts[] = [
                'kind' => 'orphan_on_sbc',
                'severity' => 'warning',
                'shortuid' => null,
                'domain' => $domainKey,
                'instance_id' => null,
                'expected_setid' => null,
                'actual_setid' => $setid,
                'detail' => "SBC domain {$domainKey} not present in catalog tenants",
            ];
        }

        $errorCount = 0;
        $warningCount = 0;
        foreach ($drifts as $d) {
            if (($d['severity'] ?? '') === 'error') {
                $errorCount++;
            } elseif (($d['severity'] ?? '') === 'warning') {
                $warningCount++;
            }
        }

        return [
            'ok' => $errorCount === 0 && $warningCount === 0,
            'checked_at' => gmdate('Y-m-d\TH:i:s\Z'),
            'summary' => [
                'tenants' => $considered,
                'sbc_domains' => count($sbcByDomain),
                'matched' => $matched,
                'drifts' => count($drifts),
                'errors' => $errorCount,
                'warnings' => $warningCount,
            ],
            'drifts' => $drifts,
        ];
    }

    /** @param  array<string, mixed>  $tenant */
    private static function tenantDomain(array $tenant): string
    {
        foreach (['sbc_domain', 'fqdn'] as $key) {
            $v = trim((string) ($tenant[$key] ?? ''));
            if ($v !== '') {
                return $v;
            }
        }

        return '';
    }

    /**
     * @param  array<string, array<string, mixed>>  $instancesById
     */
    private static function expectedSetid(string $instanceId, array $instancesById): ?int
    {
        if ($instanceId === '' || ! isset($instancesById[$instanceId])) {
            return null;
        }
        $raw = $instancesById[$instanceId]['sbc_dispatcher_setid'] ?? null;
        if ($raw === null || $raw === '') {
            return null;
        }
        $setid = (int) $raw;

        return $setid > 0 ? $setid : null;
    }
}
