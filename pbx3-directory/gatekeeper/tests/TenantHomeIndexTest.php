<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\S3Registrar;

final class TenantHomeIndexTest extends TestCase
{
    public function test_builds_slim_rows_and_skips_decommissioned(): void
    {
        $index = S3Registrar::buildTenantHomeIndex([
            [
                'shortuid' => 'dhbm8x',
                'instance_id' => 'inst-a',
                'cname' => 'dhbm8x.pbx3.com',
                'status' => 'active',
            ],
            [
                'tenant_shortuid' => 'abc789',
                'instance_id' => 'inst-b',
                'fqdn' => 'abc789.pbx3.com',
                'status' => 'maintenance',
            ],
            [
                'shortuid' => 'gone01',
                'instance_id' => 'inst-c',
                'cname' => 'gone01.pbx3.com',
                'status' => 'decommissioned',
            ],
            [
                'shortuid' => 'bad',
                'status' => 'active',
            ],
        ], '2026-07-23T22:00:00Z');

        $this->assertSame(1, $index['version']);
        $this->assertSame('2026-07-23T22:00:00Z', $index['updated_at']);
        $this->assertCount(2, $index['tenants']);
        $this->assertSame('abc789', $index['tenants'][0]['shortuid']);
        $this->assertSame('abc789.pbx3.com', $index['tenants'][0]['cname']);
        $this->assertSame('inst-b', $index['tenants'][0]['instance_id']);
        $this->assertSame('dhbm8x', $index['tenants'][1]['shortuid']);
    }

    public function test_cname_falls_back_to_shortuid(): void
    {
        $index = S3Registrar::buildTenantHomeIndex([
            [
                'shortuid' => 'vqcwd4',
                'instance_id' => 'inst-x',
                'status' => 'active',
            ],
        ]);

        $this->assertSame('vqcwd4', $index['tenants'][0]['cname']);
    }
}
