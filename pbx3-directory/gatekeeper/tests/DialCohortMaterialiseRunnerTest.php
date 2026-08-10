<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\DialCohortMaterialiseRunner;

final class DialCohortMaterialiseRunnerTest extends TestCase
{
    public function test_build_mesh_plan_full_bidirectional(): void
    {
        $members = [
            [
                'shortuid' => '9wvvnb',
                'routing_prefix' => '81',
                'fqdn' => '9wvvnb.pbx3.com',
                'instance_id' => 'inst-a',
                'api_base_url' => 'https://a.example/api',
            ],
            [
                'shortuid' => 'dhbm8x',
                'routing_prefix' => '82',
                'fqdn' => 'dhbm8x.pbx3.com',
                'instance_id' => 'inst-b',
                'api_base_url' => 'https://b.example/api',
            ],
            [
                'shortuid' => 'vqcwd4',
                'routing_prefix' => '83',
                'fqdn' => 'vqcwd4.pbx3.com',
                'instance_id' => 'inst-a',
                'api_base_url' => 'https://a.example/api',
            ],
        ];

        $plan = DialCohortMaterialiseRunner::buildMeshPlan($members, 'dc_test');
        // 3 members → 3*2 = 6 directed edges
        $this->assertCount(6, $plan);

        $byCaller = [];
        foreach ($plan as $row) {
            $byCaller[$row['cluster']][] = $row['pkey'];
            $this->assertSame('dc_test', $row['cohort_id']);
        }
        sort($byCaller['9wvvnb']);
        $this->assertSame(['82', '83'], $byCaller['9wvvnb']);
    }

    public function test_skips_members_missing_prefix(): void
    {
        $members = [
            [
                'shortuid' => '9wvvnb',
                'routing_prefix' => '81',
                'fqdn' => '9wvvnb.pbx3.com',
                'instance_id' => 'a',
                'api_base_url' => 'https://a/api',
            ],
            [
                'shortuid' => 'lonely1',
                'routing_prefix' => '',
                'fqdn' => 'lonely1.pbx3.com',
                'instance_id' => 'a',
                'api_base_url' => 'https://a/api',
            ],
        ];
        $plan = DialCohortMaterialiseRunner::buildMeshPlan($members, 'dc_x');
        $this->assertSame([], $plan);
    }

    public function test_group_plan_by_home_and_desired_pkeys(): void
    {
        $members = [
            [
                'shortuid' => '9wvvnb',
                'routing_prefix' => '81',
                'fqdn' => '9wvvnb.pbx3.com',
                'instance_id' => 'inst-a',
                'api_base_url' => 'https://a.example/api',
            ],
            [
                'shortuid' => 'dhbm8x',
                'routing_prefix' => '82',
                'fqdn' => 'dhbm8x.pbx3.com',
                'instance_id' => 'inst-b',
                'api_base_url' => 'https://b.example/api',
            ],
        ];
        $plan = DialCohortMaterialiseRunner::buildMeshPlan($members, 'dc_y');
        $homes = DialCohortMaterialiseRunner::groupPlanByHome($plan, $members);
        $this->assertCount(2, $homes);
        $this->assertArrayHasKey('https://a.example/api', $homes);
        $this->assertCount(1, $homes['https://a.example/api']['upserts']);
        $desired = DialCohortMaterialiseRunner::desiredPkeysForCaller($plan, '9wvvnb');
        $this->assertTrue(isset($desired['82']));
        $this->assertFalse(isset($desired['81']));
    }

    public function test_row_targets_tenant_matchers(): void
    {
        $this->assertTrue(DialCohortMaterialiseRunner::rowTargetsTenant(
            ['target_fqdn' => 'vqcwd4.pbx3.com', 'target_cluster' => ''],
            'vqcwd4',
            'vqcwd4.pbx3.com'
        ));
        $this->assertTrue(DialCohortMaterialiseRunner::rowTargetsTenant(
            ['target_fqdn' => '', 'target_cluster' => 'vqcwd4'],
            'vqcwd4',
            'vqcwd4.pbx3.com'
        ));
        $this->assertTrue(DialCohortMaterialiseRunner::rowTargetsTenant(
            ['target_fqdn' => 'vqcwd4.pbx3.com', 'target_cluster' => 'x'],
            'vqcwd4',
            ''
        ));
        $this->assertFalse(DialCohortMaterialiseRunner::rowTargetsTenant(
            ['target_fqdn' => 'other.pbx3.com', 'target_cluster' => 'other'],
            'vqcwd4',
            'vqcwd4.pbx3.com'
        ));
    }
}
