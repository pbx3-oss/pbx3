<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * C3 — materialise cohort mesh onto node dialalias rows + one commit per home.
 *
 * Pure planner: buildMeshPlan / desiredPkeysByCaller — unit-tested without S3/HTTP.
 */
final class DialCohortMaterialiseRunner
{
    public function __construct(
        private readonly DialCohortJobStore $jobs,
        private readonly S3Registrar $registrar,
        private readonly NodeFleetDialClient $nodes,
    ) {
    }

    /**
     * Create sync job and run to completion (or failed).
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function syncNow(string $cohortId, array $body = [], ?string $actor = null): array
    {
        $create = array_merge($body, [
            'cohort_id' => $cohortId,
            'reason' => (string) ($body['reason'] ?? 'sync'),
        ]);
        if ($actor !== null && $actor !== '') {
            $create['created_by'] = $actor;
        }
        $job = $this->jobs->create($create);

        return $this->run($cohortId, (string) $job['job_id'], $actor);
    }

    /**
     * @return array<string, mixed>
     */
    public function run(string $cohortId, string $jobId, ?string $actor = null): array
    {
        $job = $this->jobs->get($cohortId, $jobId);
        if (in_array((string) ($job['state'] ?? ''), ['completed', 'running'], true)
            && (string) ($job['state'] ?? '') === 'completed') {
            return $job;
        }

        $job['state'] = 'running';
        $job['error'] = null;
        if ($actor !== null && $actor !== '') {
            $job['updated_by'] = $actor;
        }
        $this->jobs->put($cohortId, $jobId, $job);

        try {
            $doc = $this->registrar->getDialCohort($cohortId);
            if ($doc === [] || ($doc['status'] ?? '') !== DialCohortStore::STATUS_ACTIVE) {
                throw new \RuntimeException('Cohort missing or not active', 409);
            }

            $members = $this->loadMemberSnapshots(DialCohortStore::normalizeMembers($doc['members'] ?? []));
            $plan = self::buildMeshPlan($members, $cohortId);
            $byHome = self::groupPlanByHome($plan, $members);

            $job['homes'] = array_keys($byHome);
            $job = $this->markPhase($job, 'plan', 'ok', count($plan).' projections across '.count($byHome).' home(s)');
            $this->jobs->put($cohortId, $jobId, $job);

            $pruneUnmanaged = ! empty($job['prune_unmanaged']);

            foreach ($byHome as $apiBase => $homePlan) {
                $phase = 'home:'.substr(sha1($apiBase), 0, 8);
                $job = $this->markPhase($job, $phase, 'running');
                $this->jobs->put($cohortId, $jobId, $job);

                $upserts = 0;
                $deletes = 0;
                foreach ($homePlan['upserts'] as $row) {
                    $this->nodes->upsertDialAlias($apiBase, $row);
                    $upserts++;
                }

                foreach ($homePlan['callers'] as $callerShortuid) {
                    $desired = self::desiredPkeysForCaller($plan, $callerShortuid);
                    $existing = $this->nodes->listDialAliases($apiBase, $callerShortuid);
                    foreach ($existing as $row) {
                        $pkey = (string) ($row['pkey'] ?? '');
                        $source = strtolower(trim((string) ($row['source'] ?? 'manual')));
                        $rowCohort = trim((string) ($row['cohort_id'] ?? ''));

                        $isManaged = $source === 'cohort';
                        $inDesired = $pkey !== '' && isset($desired[$pkey]);

                        if ($isManaged && $rowCohort === $cohortId && ! $inDesired) {
                            $this->nodes->deleteDialAlias($apiBase, [
                                'cluster' => $callerShortuid,
                                'pkey' => $pkey,
                                'managed_only' => true,
                            ]);
                            $deletes++;
                            continue;
                        }

                        if ($pruneUnmanaged && ! $isManaged && $pkey !== '') {
                            // Lab remedial: drop hand cross-tenant prefixes on cohort members.
                            $this->nodes->deleteDialAlias($apiBase, [
                                'cluster' => $callerShortuid,
                                'pkey' => $pkey,
                                'managed_only' => false,
                            ]);
                            $deletes++;
                        }
                    }
                }

                $this->nodes->commit($apiBase);
                $job = $this->markPhase(
                    $job,
                    $phase,
                    'ok',
                    "upserts={$upserts} deletes={$deletes} commit=ok"
                );
                $this->jobs->put($cohortId, $jobId, $job);
            }

            // Homes with members but empty peer set still need prune/commit if they appear only as callers with no peers
            // (single-member cohort): handled — byHome empty, plan empty, still complete.

            $job['state'] = 'completed';
            $job['completed_at'] = $this->registrar->nowIso();
            $job['error'] = null;
            $this->jobs->put($cohortId, $jobId, $job);

            return $job;
        } catch (\Throwable $e) {
            $job['state'] = 'failed';
            $job['error'] = $e->getMessage();
            $code = (int) $e->getCode();
            if ($code >= 400 && $code < 600) {
                $job['error_code'] = $code;
            }
            $this->jobs->put($cohortId, $jobId, $job);
            throw $e;
        }
    }

    /**
     * After decommission: delete managed rows for cohort_id on former members' homes + commit.
     *
     * @param  list<string>  $formerMembers
     * @return array{ok: bool, deletes: int, homes: list<string>}
     */
    public function pruneCohortFromNodes(string $cohortId, array $formerMembers): array
    {
        if ($formerMembers === []) {
            return ['ok' => true, 'deletes' => 0, 'homes' => []];
        }
        $snapshots = $this->loadMemberSnapshots($formerMembers);
        $byHome = [];
        foreach ($snapshots as $m) {
            $api = rtrim((string) ($m['api_base_url'] ?? ''), '/');
            if ($api === '') {
                continue;
            }
            $byHome[$api][] = (string) $m['shortuid'];
        }
        $deletes = 0;
        foreach ($byHome as $api => $callers) {
            foreach (array_unique($callers) as $caller) {
                foreach ($this->nodes->listDialAliases($api, $caller) as $row) {
                    $source = strtolower(trim((string) ($row['source'] ?? '')));
                    $rowCohort = trim((string) ($row['cohort_id'] ?? ''));
                    if ($source !== 'cohort' || $rowCohort !== $cohortId) {
                        continue;
                    }
                    $this->nodes->deleteDialAlias($api, [
                        'cluster' => $caller,
                        'pkey' => (string) ($row['pkey'] ?? ''),
                        'managed_only' => true,
                    ]);
                    $deletes++;
                }
            }
            $this->nodes->commit($api);
        }

        return ['ok' => true, 'deletes' => $deletes, 'homes' => array_keys($byHome)];
    }

    /**
     * Retry a failed job (re-run full reconcile).
     *
     * @return array<string, mixed>
     */
    public function retry(string $cohortId, string $jobId, ?string $actor = null): array
    {
        $job = $this->jobs->get($cohortId, $jobId);
        if ((string) ($job['state'] ?? '') !== 'failed') {
            throw new \InvalidArgumentException('Only failed jobs can be retried', 422);
        }
        $job['state'] = 'pending';
        $job['error'] = null;
        $job['phases'] = [];
        $this->jobs->put($cohortId, $jobId, $job);

        return $this->run($cohortId, $jobId, $actor);
    }

    // ── pure planners (tests) ─────────────────────────────────────────

    /**
     * @param  list<array{shortuid: string, routing_prefix: string, fqdn: string, instance_id: string, api_base_url: string}>  $members
     * @return list<array{cluster: string, pkey: string, target_fqdn: string, target_cluster: string, cohort_id: string, api_base_url: string, instance_id: string}>
     */
    public static function buildMeshPlan(array $members, string $cohortId): array
    {
        $ready = [];
        foreach ($members as $m) {
            $prefix = trim((string) ($m['routing_prefix'] ?? ''));
            $fqdn = strtolower(trim((string) ($m['fqdn'] ?? '')));
            $suid = strtolower(trim((string) ($m['shortuid'] ?? '')));
            if ($suid === '' || $prefix === '' || $fqdn === '') {
                continue;
            }
            $ready[] = $m;
        }

        $plan = [];
        foreach ($ready as $caller) {
            foreach ($ready as $peer) {
                if (($caller['shortuid'] ?? '') === ($peer['shortuid'] ?? '')) {
                    continue;
                }
                $plan[] = [
                    'cluster' => (string) $caller['shortuid'],
                    'pkey' => (string) $peer['routing_prefix'],
                    'target_fqdn' => strtolower((string) $peer['fqdn']),
                    'target_cluster' => (string) $peer['shortuid'],
                    'cohort_id' => $cohortId,
                    'api_base_url' => (string) ($caller['api_base_url'] ?? ''),
                    'instance_id' => (string) ($caller['instance_id'] ?? ''),
                ];
            }
        }

        return $plan;
    }

    /**
     * @param  list<array<string, mixed>>  $plan
     * @return array<string, true>
     */
    public static function desiredPkeysForCaller(array $plan, string $callerShortuid): array
    {
        $out = [];
        foreach ($plan as $row) {
            if (($row['cluster'] ?? '') === $callerShortuid) {
                $pkey = (string) ($row['pkey'] ?? '');
                if ($pkey !== '') {
                    $out[$pkey] = true;
                }
            }
        }

        return $out;
    }

    /**
     * @param  list<array<string, mixed>>  $plan
     * @param  list<array<string, mixed>>  $members
     * @return array<string, array{upserts: list<array<string, mixed>>, callers: list<string>}>
     */
    public static function groupPlanByHome(array $plan, array $members): array
    {
        $byHome = [];
        foreach ($plan as $row) {
            $api = rtrim((string) ($row['api_base_url'] ?? ''), '/');
            if ($api === '') {
                throw new \RuntimeException(
                    'Member '.(string) ($row['cluster'] ?? '?').' has no api_base_url for home instance',
                    422
                );
            }
            if (! isset($byHome[$api])) {
                $byHome[$api] = ['upserts' => [], 'callers' => []];
            }
            $byHome[$api]['upserts'][] = [
                'cluster' => $row['cluster'],
                'pkey' => $row['pkey'],
                'target_fqdn' => $row['target_fqdn'],
                'target_cluster' => $row['target_cluster'],
                'cohort_id' => $row['cohort_id'],
            ];
            $byHome[$api]['callers'][] = (string) $row['cluster'];
        }

        // Include single-member / isolate-in-cohort homes that need prune only
        foreach ($members as $m) {
            $api = rtrim((string) ($m['api_base_url'] ?? ''), '/');
            $suid = (string) ($m['shortuid'] ?? '');
            if ($api === '' || $suid === '') {
                continue;
            }
            if (! isset($byHome[$api])) {
                $byHome[$api] = ['upserts' => [], 'callers' => []];
            }
            $byHome[$api]['callers'][] = $suid;
        }

        foreach ($byHome as $api => $block) {
            $byHome[$api]['callers'] = array_values(array_unique($block['callers']));
        }

        return $byHome;
    }

    // ── private ───────────────────────────────────────────────────────

    /**
     * @param  list<string>  $shortuids
     * @return list<array{shortuid: string, routing_prefix: string, fqdn: string, instance_id: string, api_base_url: string}>
     */
    private function loadMemberSnapshots(array $shortuids): array
    {
        $catalog = $this->registrar->getCatalog();
        $apiByInstance = [];
        foreach ($catalog['instances'] ?? [] as $inst) {
            if (! is_array($inst) || empty($inst['id'])) {
                continue;
            }
            $apiByInstance[(string) $inst['id']] = rtrim((string) ($inst['api_base_url'] ?? ''), '/');
        }

        $out = [];
        foreach ($shortuids as $suid) {
            $meta = $this->registrar->getTenantMeta($suid);
            if ($meta === []) {
                throw new \RuntimeException("Tenant meta missing for cohort member {$suid}", 404);
            }
            $instanceId = trim((string) ($meta['instance_id'] ?? ''));
            $api = $apiByInstance[$instanceId] ?? '';
            if ($api === '') {
                throw new \RuntimeException(
                    "No api_base_url for instance {$instanceId} (member {$suid})",
                    422
                );
            }
            $fqdn = strtolower(trim((string) ($meta['fqdn'] ?? $meta['cname'] ?? '')));
            $out[] = [
                'shortuid' => $suid,
                'routing_prefix' => (string) ($meta['routing_prefix'] ?? ''),
                'fqdn' => $fqdn,
                'instance_id' => $instanceId,
                'api_base_url' => $api,
            ];
        }

        return $out;
    }

    /**
     * @param  array<string, mixed>  $job
     * @return array<string, mixed>
     */
    private function markPhase(array $job, string $phase, string $status, ?string $message = null): array
    {
        $phases = is_array($job['phases'] ?? null) ? $job['phases'] : [];
        $row = $phases[$phase] ?? [];
        $row['status'] = $status;
        if ($status === 'running') {
            $row['started_at'] = gmdate('Y-m-d\TH:i:s\Z');
        }
        if (in_array($status, ['ok', 'failed', 'skipped'], true)) {
            $row['finished_at'] = gmdate('Y-m-d\TH:i:s\Z');
        }
        if ($message !== null) {
            $row['message'] = $message;
        }
        $phases[$phase] = $row;
        $job['phases'] = $phases;

        return $job;
    }
}
