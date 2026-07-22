<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Scheduled catalog probe: /up → SQLite health → optional S3 last_seen_at → notify on transition.
 */
final class FleetInstanceProbe
{
    public function __construct(
        private readonly S3Registrar $registrar,
        private readonly NotifyDispatcher $notify,
        private readonly int $timeoutSeconds = 8,
    ) {
    }

    /**
     * @return array{probed:int, skipped:int, down:int, cleared:int, errors:list<string>}
     */
    public function run(): array
    {
        $catalog = $this->registrar->getCatalog();
        $instances = $catalog['instances'] ?? [];
        if (! is_array($instances)) {
            $instances = [];
        }

        $probed = 0;
        $skipped = 0;
        $down = 0;
        $cleared = 0;
        $errors = [];

        foreach ($instances as $row) {
            if (! is_array($row)) {
                $skipped++;
                continue;
            }
            $id = trim((string) ($row['id'] ?? ''));
            $status = (string) ($row['status'] ?? '');
            $api = trim((string) ($row['api_base_url'] ?? ''));
            if ($id === '' || $api === '') {
                $skipped++;
                continue;
            }
            if ($status === 'decommissioned' || $status === 'maintenance') {
                $skipped++;
                continue;
            }

            $ok = false;
            $rttMs = null;
            try {
                $result = InstanceUpProbe::probe($api, $this->timeoutSeconds);
                $ok = $result['ok'];
                $rttMs = $result['rtt_ms'];
            } catch (\Throwable $e) {
                $errors[] = "{$id}: probe exception: ".$e->getMessage();
                $ok = false;
                $rttMs = null;
            }

            $probed++;
            $transition = null;
            try {
                $transition = InstanceHealthStore::recordProbe($id, $ok, $rttMs);
            } catch (\Throwable $e) {
                $errors[] = "{$id}: health store: ".$e->getMessage();
                continue;
            }

            if ($ok) {
                try {
                    $this->registrar->touchLastSeenAt($id);
                } catch (\Throwable $e) {
                    $errors[] = "{$id}: last_seen_at: ".$e->getMessage();
                }
                try {
                    $egress = InstanceEgressQualifyProbe::probe($api, $this->timeoutSeconds);
                    InstanceHealthStore::recordEgress($id, $egress['state'], $egress['rtt_ms']);
                    if ($egress['error'] !== null) {
                        $errors[] = "{$id}: egress: ".$egress['error'];
                    }
                } catch (\Throwable $e) {
                    $errors[] = "{$id}: egress: ".$e->getMessage();
                    try {
                        InstanceHealthStore::recordEgress($id, 'Unknown', null);
                    } catch (\Throwable) {
                        // ignore
                    }
                }
            } else {
                try {
                    InstanceHealthStore::recordEgress($id, 'Unknown', null);
                } catch (\Throwable $e) {
                    $errors[] = "{$id}: egress clear: ".$e->getMessage();
                }
            }

            if ($transition === 'down' || $transition === 'cleared') {
                try {
                    $this->notify->notifyInstanceReachability($row, $transition);
                    if ($transition === 'down') {
                        $down++;
                    } else {
                        $cleared++;
                    }
                } catch (\Throwable $e) {
                    $errors[] = "{$id}: notify: ".$e->getMessage();
                }
            }
        }

        return [
            'probed' => $probed,
            'skipped' => $skipped,
            'down' => $down,
            'cleared' => $cleared,
            'errors' => $errors,
        ];
    }
}
