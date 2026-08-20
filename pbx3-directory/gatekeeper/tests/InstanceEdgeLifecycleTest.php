<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceEdgeLifecycle;
use Pbx3\Gatekeeper\SbcFleetClient;

final class InstanceEdgeLifecycleTest extends TestCase
{
    public function test_retire_skips_empty_instance_id(): void
    {
        $result = InstanceEdgeLifecycle::retireFail2banWhitelist(new SbcFleetClient(), '  ');
        $this->assertFalse($result['ok']);
        $this->assertSame('instance_id required', $result['error']);
    }

    public function test_attach_fail2ban_retire_adds_key(): void
    {
        $base = ['instance' => ['id' => 'kid1', 'status' => 'decommissioned']];
        $out = InstanceEdgeLifecycle::attachFail2banRetire($base, new SbcFleetClient(), 'kid1');
        $this->assertArrayHasKey('fail2ban_retire', $out);
        $this->assertIsArray($out['fail2ban_retire']);
    }
}
