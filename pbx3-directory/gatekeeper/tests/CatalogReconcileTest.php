<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\CatalogReconcile;

final class CatalogReconcileTest extends TestCase
{
    public function test_matched_tenant_is_ok(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'fqdn' => '08jzwn.pbx3.com', 'sbc_dispatcher_setid' => 2],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => '08jzwn',
                    'fqdn' => 'affcot.pbx3.com',
                ],
            ],
            [
                ['domain' => 'affcot.pbx3.com', 'setid' => 2],
                ['domain' => '08jzwn.pbx3.com', 'setid' => 2],
            ]
        );

        $this->assertTrue($report['ok']);
        $this->assertSame(1, $report['summary']['matched']);
        $this->assertSame(0, $report['summary']['drifts']);
        $this->assertSame([], $report['drifts']);
    }

    public function test_setid_mismatch(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'sbc_dispatcher_setid' => 2],
                    ['id' => 'bzy54n', 'sbc_dispatcher_setid' => 3],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => 'bzy54n',
                    'fqdn' => 'affcot.pbx3.com',
                ],
            ],
            [
                ['domain' => 'affcot.pbx3.com', 'setid' => 2],
            ]
        );

        $this->assertFalse($report['ok']);
        $this->assertSame('setid_mismatch', $report['drifts'][0]['kind']);
        $this->assertSame(3, $report['drifts'][0]['expected_setid']);
        $this->assertSame(2, $report['drifts'][0]['actual_setid']);
    }

    public function test_missing_on_sbc(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'sbc_dispatcher_setid' => 2],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => '08jzwn',
                    'fqdn' => 'affcot.pbx3.com',
                ],
            ],
            []
        );

        $this->assertFalse($report['ok']);
        $this->assertSame('missing_on_sbc', $report['drifts'][0]['kind']);
    }

    public function test_orphan_on_sbc_skips_instance_fqdn(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'fqdn' => '08jzwn.pbx3.com', 'sbc_dispatcher_setid' => 2],
                ],
            ],
            [],
            [
                ['domain' => '08jzwn.pbx3.com', 'setid' => 2],
                ['domain' => 'ghost.pbx3.com', 'setid' => 9],
            ]
        );

        $this->assertFalse($report['ok']);
        $this->assertCount(1, $report['drifts']);
        $this->assertSame('orphan_on_sbc', $report['drifts'][0]['kind']);
        $this->assertSame('ghost.pbx3.com', $report['drifts'][0]['domain']);
        $this->assertSame('warning', $report['drifts'][0]['severity']);
    }

    public function test_unresolvable_without_instance_setid(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'fqdn' => '08jzwn.pbx3.com'],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => '08jzwn',
                    'fqdn' => 'affcot.pbx3.com',
                ],
            ],
            [
                ['domain' => 'affcot.pbx3.com', 'setid' => 2],
            ]
        );

        $this->assertFalse($report['ok']);
        $this->assertSame('unresolvable_expected_setid', $report['drifts'][0]['kind']);
        $this->assertSame('warning', $report['drifts'][0]['severity']);
    }

    public function test_prefers_sbc_domain_over_fqdn(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'sbc_dispatcher_setid' => 2],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => '08jzwn',
                    'fqdn' => 'ignored.example',
                    'sbc_domain' => 'affcot.pbx3.com',
                ],
            ],
            [
                ['domain' => 'affcot.pbx3.com', 'setid' => 2],
            ]
        );

        $this->assertTrue($report['ok']);
        $this->assertSame(1, $report['summary']['matched']);
    }

    public function test_plan_project_only_setid_mismatch(): void
    {
        $report = CatalogReconcile::compare(
            [
                'instances' => [
                    ['id' => '08jzwn', 'sbc_dispatcher_setid' => 2],
                    ['id' => 'bzy54n', 'sbc_dispatcher_setid' => 3],
                ],
            ],
            [
                [
                    'shortuid' => '9wvvnb',
                    'instance_id' => 'bzy54n',
                    'fqdn' => 'affcot.pbx3.com',
                ],
                [
                    'shortuid' => 'ghost1',
                    'instance_id' => '08jzwn',
                    'fqdn' => 'ghost.pbx3.com',
                ],
            ],
            [
                ['domain' => 'affcot.pbx3.com', 'setid' => 2],
            ]
        );

        $plan = CatalogReconcile::planProject($report);
        $this->assertCount(1, $plan['actions']);
        $this->assertSame('affcot.pbx3.com', $plan['actions'][0]['domain']);
        $this->assertSame(2, $plan['actions'][0]['from_setid']);
        $this->assertSame(3, $plan['actions'][0]['to_setid']);

        $skipKinds = array_column($plan['skipped'], 'kind');
        $this->assertContains('missing_on_sbc', $skipKinds);
    }

    public function test_plan_project_domain_filter(): void
    {
        $report = [
            'drifts' => [
                [
                    'kind' => 'setid_mismatch',
                    'domain' => 'a.pbx3.com',
                    'expected_setid' => 2,
                    'actual_setid' => 3,
                    'shortuid' => 'aaaaaa',
                ],
                [
                    'kind' => 'setid_mismatch',
                    'domain' => 'b.pbx3.com',
                    'expected_setid' => 3,
                    'actual_setid' => 2,
                    'shortuid' => 'bbbbbb',
                ],
            ],
        ];
        $plan = CatalogReconcile::planProject($report, ['a.pbx3.com' => true]);
        $this->assertCount(1, $plan['actions']);
        $this->assertSame('a.pbx3.com', $plan['actions'][0]['domain']);
    }
}
