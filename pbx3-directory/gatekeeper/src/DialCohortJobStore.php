<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * C3 — dial cohort materialise jobs under catalog/dial-cohorts/{id}/jobs/{job_id}.json
 */
final class DialCohortJobStore
{
    public function __construct(
        private readonly S3Registrar $registrar,
    ) {
    }

    /**
     * @param  array<string, mixed>  $body  cohort_id, reason?, created_by?, prune_unmanaged?
     * @return array<string, mixed>
     */
    public function create(array $body): array
    {
        $cohortId = trim((string) ($body['cohort_id'] ?? ''));
        if ($cohortId === '') {
            throw new \InvalidArgumentException('cohort_id required', 422);
        }
        $doc = $this->registrar->getDialCohort($cohortId);
        if ($doc === []) {
            throw new \RuntimeException("Dial cohort not found: {$cohortId}", 404);
        }

        $jobId = (string) ($body['job_id'] ?? $this->newJobId());
        $now = $this->registrar->nowIso();
        $job = [
            'schema_version' => 1,
            'job_id' => $jobId,
            'cohort_id' => $cohortId,
            'cohort_name' => (string) ($doc['name'] ?? ''),
            'reason' => (string) ($body['reason'] ?? 'sync'),
            'state' => 'pending',
            'prune_unmanaged' => ! array_key_exists('prune_unmanaged', $body) || ! empty($body['prune_unmanaged']),
            'homes' => [],
            'phases' => [],
            'error' => null,
            'created_by' => isset($body['created_by']) && is_string($body['created_by']) ? $body['created_by'] : null,
            'updated_by' => isset($body['created_by']) && is_string($body['created_by']) ? $body['created_by'] : null,
            'created_at' => $now,
            'updated_at' => $now,
            'completed_at' => null,
        ];
        $this->put($cohortId, $jobId, $job);

        return $job;
    }

    /** @return array<string, mixed> */
    public function get(string $cohortId, string $jobId): array
    {
        $job = $this->registrar->getDialCohortJob($cohortId, $jobId);
        if ($job === []) {
            throw new \RuntimeException("Dial cohort job not found: {$jobId}", 404);
        }

        return $job;
    }

    /** @param array<string, mixed> $job */
    public function put(string $cohortId, string $jobId, array $job): void
    {
        $job['job_id'] = $jobId;
        $job['cohort_id'] = $cohortId;
        $job['updated_at'] = $this->registrar->nowIso();
        $this->registrar->putDialCohortJob($cohortId, $jobId, $job);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listForCohort(string $cohortId, int $limit = 20): array
    {
        $ids = $this->registrar->listDialCohortJobIds($cohortId);
        rsort($ids);
        $out = [];
        foreach (array_slice($ids, 0, max(1, $limit)) as $jobId) {
            $job = $this->registrar->getDialCohortJob($cohortId, $jobId);
            if ($job !== []) {
                $out[] = $job;
            }
        }

        return $out;
    }

    private function newJobId(): string
    {
        return 'dcj_'.bin2hex(random_bytes(12));
    }
}
