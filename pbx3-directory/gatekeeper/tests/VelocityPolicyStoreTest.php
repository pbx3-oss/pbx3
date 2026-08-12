<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\VelocityPolicyStore;

final class VelocityPolicyStoreTest extends TestCase
{
    public function test_defaults_match_lab_env_semantics(): void
    {
        $d = VelocityPolicyStore::defaults('2026-08-11T00:00:00Z');
        $this->assertSame(1, $d['version']);
        $this->assertSame(10, $d['irsf']['n']);
        $this->assertSame(5, $d['irsf']['t_minutes']);
        $this->assertSame(30, $d['irsf']['q_minutes']);
        $this->assertSame(['0900', '+44900', '0044900'], $d['irsf']['prefixes']);
        $this->assertFalse($d['irsf']['act_enabled']);
        $this->assertTrue($d['detectors']['irsf']);
        $this->assertFalse($d['detectors']['off_hours']);
    }

    public function test_normalize_accepts_comma_prefixes_and_clamps(): void
    {
        $doc = VelocityPolicyStore::normalize([
            'irsf' => [
                'n' => 0,
                'prefixes' => '0900, 070',
                'act_enabled' => 'true',
            ],
            'allowlist_extensions' => ['1001', '', 'vip'],
        ], '2026-08-11T00:00:00Z');

        $this->assertSame(1, $doc['irsf']['n']);
        $this->assertSame(['0900', '070'], $doc['irsf']['prefixes']);
        $this->assertTrue($doc['irsf']['act_enabled']);
        $this->assertSame(['1001', 'vip'], $doc['allowlist_extensions']);
    }

    public function test_normalize_rejects_empty_prefixes(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        VelocityPolicyStore::normalize([
            'irsf' => ['prefixes' => []],
        ], '2026-08-11T00:00:00Z');
    }
}
