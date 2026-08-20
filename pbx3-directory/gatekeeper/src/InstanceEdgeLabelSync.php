<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Push instance friendly Name to SBC Peer + dispatcher descriptions (#5b).
 */
final class InstanceEdgeLabelSync
{
    public static function pushToSbc(string $instanceId, string $label, int $setid): void
    {
        if ($setid < 1) {
            return;
        }
        $label = trim($label);
        if ($label === '') {
            throw new \InvalidArgumentException('label required for SBC sync', 422);
        }

        $result = (new SbcFleetClient())->syncNodeLabel($instanceId, $label, $setid);
        if (empty($result['ok'])) {
            $msg = (string) ($result['message'] ?? $result['errors'][0] ?? 'SBC peer label sync failed');
            throw new \RuntimeException($msg, 502);
        }
    }
}
