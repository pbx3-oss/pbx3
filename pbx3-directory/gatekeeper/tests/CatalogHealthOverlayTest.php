<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\CatalogHealthOverlay;
use Pbx3\Gatekeeper\InstanceHealthStore;
use Pbx3\Gatekeeper\UserStore;

final class CatalogHealthOverlayTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-overlay-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        UserStore::resetForTests();
    }

    protected function tearDown(): void
    {
        UserStore::resetForTests();
        if (is_file($this->dbPath)) {
            @unlink($this->dbPath);
        }
        putenv('GATEKEEPER_AUTH_DB');
        unset($_ENV['GATEKEEPER_AUTH_DB']);
    }

    public function test_record_probe_persists_rtt_on_success_only(): void
    {
        InstanceHealthStore::recordProbe('node1', true, 42);
        $row = InstanceHealthStore::get('node1');
        $this->assertTrue($row['reachable']);
        $this->assertSame(42, $row['last_rtt_ms']);

        InstanceHealthStore::recordProbe('node1', false);
        $row = InstanceHealthStore::get('node1');
        $this->assertSame(42, $row['last_rtt_ms'], 'failed probe keeps last successful RTT');

        InstanceHealthStore::recordProbe('node1', true, 17);
        $row = InstanceHealthStore::get('node1');
        $this->assertSame(17, $row['last_rtt_ms']);
    }

    public function test_enrich_overlays_health_and_pauses_maintenance(): void
    {
        InstanceHealthStore::recordProbe('active1', true, 33);
        InstanceHealthStore::recordEgress('active1', 'Avail', 12);

        $catalog = [
            'version' => 1,
            'instances' => [
                [
                    'id' => 'active1',
                    'fqdn' => 'a.example',
                    'api_base_url' => 'https://a.example/api',
                    'label' => 'A',
                    'status' => 'active',
                    'last_seen_at' => '2026-07-18T12:00:00Z',
                ],
                [
                    'id' => 'maint1',
                    'fqdn' => 'm.example',
                    'api_base_url' => 'https://m.example/api',
                    'label' => 'M',
                    'status' => 'maintenance',
                ],
            ],
        ];

        $out = CatalogHealthOverlay::enrich($catalog);
        $this->assertSame(33, $out['instances'][0]['health']['last_rtt_ms']);
        $this->assertTrue($out['instances'][0]['health']['reachable']);
        $this->assertFalse($out['instances'][0]['health']['probe_paused']);
        $this->assertSame('Avail', $out['instances'][0]['health']['egress_state']);
        $this->assertSame(12, $out['instances'][0]['health']['egress_rtt_ms']);
        $this->assertTrue($out['instances'][1]['health']['probe_paused']);
        $this->assertNull($out['instances'][1]['health']['reachable']);
        $this->assertNull($out['instances'][1]['health']['last_rtt_ms']);
        $this->assertNull($out['instances'][1]['health']['egress_state']);
        $this->assertSame('2026-07-18T12:00:00Z', $out['instances'][0]['last_seen_at']);
    }
}
