<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Enrich GET /api/v1/catalog with per-instance probe health for SPA badges.
 * Does not mutate S3 HoR — overlay is API-only (Rule 8).
 */
final class CatalogHealthOverlay
{
    /**
     * @param array<string, mixed> $catalog
     * @return array<string, mixed>
     */
    public static function enrich(array $catalog): array
    {
        $instances = $catalog['instances'] ?? [];
        if (! is_array($instances)) {
            return $catalog;
        }

        $out = [];
        foreach ($instances as $row) {
            if (! is_array($row)) {
                continue;
            }
            $id = trim((string) ($row['id'] ?? ''));
            $status = strtolower(trim((string) ($row['status'] ?? 'active')));
            $paused = $status === 'maintenance' || $status === 'decommissioned';

            $health = [
                'probe_paused' => $paused,
                'reachable' => null,
                'consecutive_misses' => null,
                'last_ok_at' => null,
                'last_probe_at' => null,
                'last_rtt_ms' => null,
                'egress_state' => null,
                'egress_rtt_ms' => null,
                'egress_probed_at' => null,
            ];

            if (! $paused && $id !== '') {
                $stored = InstanceHealthStore::get($id);
                if ($stored !== null) {
                    $health['reachable'] = $stored['reachable'];
                    $health['consecutive_misses'] = $stored['consecutive_misses'];
                    $health['last_ok_at'] = $stored['last_ok_at'];
                    $health['last_probe_at'] = $stored['last_probe_at'];
                    $health['last_rtt_ms'] = $stored['last_rtt_ms'];
                    $health['egress_state'] = $stored['egress_state'];
                    $health['egress_rtt_ms'] = $stored['egress_rtt_ms'];
                    $health['egress_probed_at'] = $stored['egress_probed_at'];
                }
            }

            $row['health'] = $health;
            $out[] = $row;
        }

        $catalog['instances'] = $out;

        return $catalog;
    }
}
