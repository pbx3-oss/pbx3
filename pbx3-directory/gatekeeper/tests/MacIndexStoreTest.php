<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\MacIndexStore;
use Pbx3\Gatekeeper\Tests\Support\InMemoryMacIndexPersistence;

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

    public function test_claim_creates_and_projects_map(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $out = $store->claim([
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'tenant_shortuid' => 'hf3zzv',
            'instance_id' => 'inst-a',
        ]);
        $this->assertTrue($out['created']);
        $this->assertSame('aabbccddeeff', $out['mac']);
        $this->assertCount(1, $store->getIndex()['entries']);
        $this->assertStringContainsString('~*^aabbccddeeff$ "http://44.196.98.191:41363";', $fake->getProvisionMacMap());
        $this->assertStringNotContainsString('hf3zzv', $fake->getProvisionMacMap());
        MacIndexStore::assertMapHasNoSecrets($fake->getProvisionMacMap());
    }

    public function test_claim_conflict_rejects_other_instance(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'tenant1',
            'instance_id' => 'inst-a',
        ]);

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(409);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'tenant2',
            'instance_id' => 'inst-b',
        ]);
    }

    public function test_claim_same_instance_reclaim_ok(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'tenant1',
            'instance_id' => 'inst-a',
        ]);
        $again = $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'tenant1',
            'instance_id' => 'inst-a',
        ]);
        $this->assertFalse($again['created']);
        $this->assertCount(1, $store->getIndex()['entries']);
    }

    public function test_clear_removes_map_line(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'hf3zzv',
            'instance_id' => 'inst-a',
        ]);
        $this->assertStringContainsString('aabbccddeeff', $fake->getProvisionMacMap());

        $cleared = $store->clear(['mac' => 'aabbccddeeff']);
        $this->assertTrue($cleared['cleared']);
        $this->assertStringNotContainsString('aabbccddeeff', $fake->getProvisionMacMap());
        $this->assertSame([], $store->getIndex()['entries']);
    }

    public function test_rewrite_tenant_instance_updates_map_upstream(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'move01',
            'instance_id' => 'inst-a',
        ]);
        $store->claim([
            'mac' => '112233445566',
            'tenant_shortuid' => 'stay01',
            'instance_id' => 'inst-a',
        ]);

        $rew = $store->rewriteTenantInstance('move01', 'inst-b');
        $this->assertSame(1, $rew['rewritten']);
        $map = $fake->getProvisionMacMap();
        $this->assertStringContainsString('~*^aabbccddeeff$ "http://bzy54n.pbx3.com:41363";', $map);
        $this->assertStringContainsString('~*^112233445566$ "http://44.196.98.191:41363";', $map);
    }

    public function test_compare_index_to_map_match_ok(): void
    {
        $instances = [
            'inst-a' => ['id' => 'inst-a', 'sbc_backend_uri' => 'sip:10.0.0.1:5060'],
        ];
        $index = [
            'entries' => [
                ['mac' => 'aabbccddeeff', 'tenant_shortuid' => 't1', 'instance_id' => 'inst-a'],
            ],
        ];
        $map = MacIndexStore::buildNginxMap($index, $instances);
        $report = MacIndexStore::compareIndexToMap($index, $map, $instances);
        $this->assertTrue($report['ok']);
        $this->assertSame(1, $report['summary']['matched']);
        $this->assertSame(0, $report['summary']['drifts']);
    }

    public function test_compare_detects_missing_extra_and_mismatch(): void
    {
        $instances = [
            'inst-a' => ['id' => 'inst-a', 'fqdn' => 'a.pbx3.com'],
            'inst-b' => ['id' => 'inst-b', 'fqdn' => 'b.pbx3.com'],
        ];
        $index = [
            'entries' => [
                ['mac' => 'aaaaaaaaaaaa', 'tenant_shortuid' => 't1', 'instance_id' => 'inst-a'],
                ['mac' => 'bbbbbbbbbbbb', 'tenant_shortuid' => 't1', 'instance_id' => 'inst-a'],
            ],
        ];
        // Stale map: missing aaaa, wrong upstream for bbbb, extra cccc
        $stale = <<<'MAP'
map $provision_mac $provision_upstream {
    default "";
    ~*^bbbbbbbbbbbb$ "http://b.pbx3.com:41363";
    ~*^cccccccccccc$ "http://a.pbx3.com:41363";
}
MAP;
        $report = MacIndexStore::compareIndexToMap($index, $stale, $instances);
        $this->assertFalse($report['ok']);
        $kinds = array_column($report['drifts'], 'kind');
        $this->assertContains('map_missing_mac', $kinds);
        $this->assertContains('map_upstream_mismatch', $kinds);
        $this->assertContains('map_extra_mac', $kinds);
    }

    public function test_reconcile_map_clears_after_project(): void
    {
        $fake = new InMemoryMacIndexPersistence();
        $store = new MacIndexStore($fake);
        $store->claim([
            'mac' => 'aabbccddeeff',
            'tenant_shortuid' => 'hf3zzv',
            'instance_id' => 'inst-a',
        ]);
        // Corrupt map
        $fake->putProvisionMacMap("map \$provision_mac \$provision_upstream {\n    default \"\";\n}\n");
        $before = $store->reconcileMap();
        $this->assertFalse($before['ok']);
        $this->assertSame('map_missing_mac', $before['drifts'][0]['kind']);

        $store->projectMap();
        $after = $store->reconcileMap();
        $this->assertTrue($after['ok']);
        $this->assertSame(1, $after['summary']['matched']);
    }
}
