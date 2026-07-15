<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\TenantMoveRunner;

final class TenantMoveJobControlTest extends TestCase
{
    public function test_failed_phase_name_from_phases(): void
    {
        $job = [
            'state' => 'failed',
            'phases' => [
                'preflight' => ['status' => 'ok'],
                'exporting' => ['status' => 'failed', 'message' => 'boom'],
            ],
        ];
        $this->assertSame('exporting', TenantMoveRunner::failedPhaseName($job));
    }

    public function test_failed_phase_name_null_when_none(): void
    {
        $this->assertNull(TenantMoveRunner::failedPhaseName([
            'phases' => ['preflight' => ['status' => 'ok']],
        ]));
    }
}
