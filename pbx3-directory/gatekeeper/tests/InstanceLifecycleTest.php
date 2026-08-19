<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\CatalogIntegrityException;
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

    public function test_active_tenants_for_instance_omits_decommissioned_and_other_homes(): void
    {
        $metas = [
            ['shortuid' => 'bbb', 'instance_id' => 'inst1', 'status' => 'decommissioned', 'fqdn' => 'b.pbx3.com'],
            ['shortuid' => 'aaa', 'instance_id' => 'inst1', 'status' => 'active', 'fqdn' => 'a.pbx3.com', 'pkey' => 'Alpha'],
            ['shortuid' => 'ccc', 'instance_id' => 'inst2', 'status' => 'active', 'fqdn' => 'c.pbx3.com'],
        ];

        $this->assertSame(
            [
                [
                    'shortuid' => 'aaa',
                    'fqdn' => 'a.pbx3.com',
                    'pkey' => 'Alpha',
                    'cname' => '',
                ],
            ],
            S3Registrar::activeTenantsForInstance('inst1', $metas)
        );
    }

    public function test_assert_can_decommission_instance_throws_with_blockers(): void
    {
        $this->expectException(CatalogIntegrityException::class);
        $this->expectExceptionCode(422);
        S3Registrar::assertCanDecommissionInstanceWithMetas('kid123', [
            ['shortuid' => 'site1', 'instance_id' => 'kid123', 'status' => 'active', 'pkey' => 'LabOne'],
        ]);
    }

    public function test_assert_can_decommission_instance_allows_when_clear(): void
    {
        S3Registrar::assertCanDecommissionInstanceWithMetas('kid123', [
            ['shortuid' => 'site1', 'instance_id' => 'kid123', 'status' => 'decommissioned'],
            ['shortuid' => 'site2', 'instance_id' => 'other', 'status' => 'active'],
        ]);
        $this->addToAssertionCount(1);
    }
}
