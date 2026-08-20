<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * SBC edge side-effects on instance lifecycle (#5e Fail2ban whitelist retire).
 */
final class InstanceEdgeLifecycle
{
    /**
     * Drop fleet-home Fail2ban whitelist rows on the SBC (decommission / catalog retire).
     *
     * @return array<string, mixed>
     */
    public static function retireFail2banWhitelist(SbcFleetClient $sbc, string $instanceId): array
    {
        $instanceId = trim($instanceId);
        if ($instanceId === '') {
            return ['ok' => false, 'error' => 'instance_id required'];
        }

        try {
            return $sbc->retireNodeWhitelist($instanceId);
        } catch (\Throwable $e) {
            error_log('[gatekeeper] fail2ban whitelist retire failed: '.$e->getMessage());

            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * @param  array<string, mixed>  $result
     * @return array<string, mixed>
     */
    public static function attachFail2banRetire(array $result, SbcFleetClient $sbc, string $instanceId): array
    {
        $result['fail2ban_retire'] = self::retireFail2banWhitelist($sbc, $instanceId);

        return $result;
    }
}
