<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceUpProbe;
use Pbx3\Gatekeeper\S3Registrar;

final class InstanceLifecycleTest extends TestCase
{
    public function test_up_url_strips_api_suffix(): void
    {
        $this->assertSame(
            'https://08jzwn.pbx3.com:44300/up',
            InstanceUpProbe::upUrl('https://08jzwn.pbx3.com:44300/api')
        );
        $this->assertSame(
            'https://08jzwn.pbx3.com:44300/up',
            InstanceUpProbe::upUrl('https://08jzwn.pbx3.com:44300/api/')
        );
    }

    public function test_up_url_appends_when_no_api_suffix(): void
    {
        $this->assertSame(
            'https://example.com/up',
            InstanceUpProbe::upUrl('https://example.com')
        );
    }

    public function test_merge_instance_patch_status_and_notes(): void
    {
        $merged = S3Registrar::mergeInstancePatch(
            [
                'id' => 'abc',
                'label' => 'gold',
                'status' => 'active',
                'fqdn' => 'x.example',
            ],
            [
                'status' => 'maintenance',
                'notes' => 'draining',
                'verify_up' => true, // not patchable — ignored
            ]
        );
        $this->assertSame('maintenance', $merged['status']);
        $this->assertSame('draining', $merged['notes']);
        $this->assertSame('gold', $merged['label']);
        $this->assertArrayNotHasKey('verify_up', $merged);
    }

    public function test_merge_rejects_bad_status(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionCode(422);
        S3Registrar::mergeInstancePatch(['id' => 'x', 'status' => 'active'], ['status' => 'gone']);
    }

    public function test_statuses_match_schema(): void
    {
        $this->assertSame(['active', 'maintenance', 'decommissioned'], S3Registrar::STATUSES);
    }

    public function test_assert_decommissioned_for_catalog_remove(): void
    {
        S3Registrar::assertDecommissionedForCatalogRemove(['id' => 'x', 'status' => 'decommissioned']);
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionCode(422);
        S3Registrar::assertDecommissionedForCatalogRemove(['id' => 'x', 'status' => 'active']);
    }
}
