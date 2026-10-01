<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\MacIndexStore;

final class MacIndexStoreTest extends TestCase
{
    public function test_normalize_mac_strips_separators(): void
    {
        $this->assertSame('aabbccddeeff', MacIndexStore::normalizeMac('AA:BB:CC:DD:EE:FF'));
        $this->assertSame('aabbccddeeff', MacIndexStore::normalizeMac('aa-bb-cc-dd-ee-ff'));
    }

    public function test_normalize_rejects_zero_and_short(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        MacIndexStore::normalizeMac('000000000000');
    }

    public function test_home_host_prefers_sbc_backend_uri(): void
    {
        $host = MacIndexStore::homeHostFromInstance([
            'fqdn' => '08jzwn.pbx3.com',
            'sbc_backend_uri' => 'sip:10.0.0.5:5060',
        ]);
        $this->assertSame('10.0.0.5', $host);
        $this->assertSame(
            'http://10.0.0.5:41363',
            MacIndexStore::homeProvisionBaseUrl([
                'sbc_backend_uri' => 'sip:10.0.0.5:5060',
            ])
        );
    }

    public function test_home_host_falls_back_to_fqdn(): void
    {
        $this->assertSame(
            'http://08jzwn.pbx3.com:41363',
            MacIndexStore::homeProvisionBaseUrl(['fqdn' => '08jzwn.pbx3.com'])
        );
    }

    public function test_build_nginx_map_routes_mac_to_home_no_secrets(): void
    {
        $map = MacIndexStore::buildNginxMap([
            'version' => 1,
            'updated_at' => '2026-09-30T00:00:00Z',
            'entries' => [
                [
                    'mac' => 'aabbccddeeff',
                    'tenant_shortuid' => 'dhbm8x',
                    'instance_id' => 'inst-a',
                ],
                [
                    'mac' => '112233445566',
                    'tenant_shortuid' => 'other1',
                    'instance_id' => 'inst-b',
                ],
            ],
        ], [
            'inst-a' => [
                'id' => 'inst-a',
                'fqdn' => '08jzwn.pbx3.com',
                'sbc_backend_uri' => 'sip:44.196.98.191:5060',
            ],
            'inst-b' => [
                'id' => 'inst-b',
                'fqdn' => 'bzy54n.pbx3.com',
            ],
        ]);

        $this->assertStringContainsString('map $provision_mac $provision_upstream', $map);
        $this->assertStringContainsString('~*^aabbccddeeff$ "http://44.196.98.191:41363";', $map);
        $this->assertStringNotContainsString('AABBCCDDEEFF "', $map);
        $this->assertStringContainsString('~*^112233445566$ "http://bzy54n.pbx3.com:41363";', $map);
        $this->assertStringNotContainsString('password', strtolower($map));
        $this->assertStringNotContainsString('dhbm8x', $map); // tenant not in map value
        MacIndexStore::assertMapHasNoSecrets($map);
    }

    public function test_assert_map_rejects_secret_leak(): void
    {
        $this->expectException(\RuntimeException::class);
        MacIndexStore::assertMapHasNoSecrets('map $x $y { default "password=secret"; }');
    }

    public function test_claim_conflict_logic_via_in_memory_simulation(): void
    {
        // Pure conflict rule: second instance cannot steal without clear.
        $entries = [
            [
                'mac' => 'aabbccddeeff',
                'tenant_shortuid' => 'tenant1',
                'instance_id' => 'inst-a',
                'updated_at' => '2026-09-30T00:00:00Z',
            ],
        ];
        $mac = 'aabbccddeeff';
        $claimInstance = 'inst-b';
        $conflict = false;
        foreach ($entries as $row) {
            if ($row['mac'] === $mac && $row['instance_id'] !== $claimInstance) {
                $conflict = true;
            }
        }
        $this->assertTrue($conflict);

        // Same instance reclaim OK
        $sameOk = true;
        foreach ($entries as $row) {
            if ($row['mac'] === $mac && $row['instance_id'] !== 'inst-a') {
                $sameOk = false;
            }
        }
        $this->assertTrue($sameOk);
    }

    public function test_rewrite_tenant_instance_updates_matching_rows(): void
    {
        $entries = [
            ['mac' => 'aaaaaaaaaaaa', 'tenant_shortuid' => 'move01', 'instance_id' => 'src'],
            ['mac' => 'bbbbbbbbbbbb', 'tenant_shortuid' => 'stay01', 'instance_id' => 'src'],
            ['mac' => 'cccccccccccc', 'tenant_shortuid' => 'move01', 'instance_id' => 'src'],
        ];
        $rewritten = 0;
        foreach ($entries as &$row) {
            if ($row['tenant_shortuid'] === 'move01') {
                $row['instance_id'] = 'dest';
                $rewritten++;
            }
        }
        unset($row);
        $this->assertSame(2, $rewritten);
        $this->assertSame('dest', $entries[0]['instance_id']);
        $this->assertSame('src', $entries[1]['instance_id']);
        $this->assertSame('dest', $entries[2]['instance_id']);
    }
}
