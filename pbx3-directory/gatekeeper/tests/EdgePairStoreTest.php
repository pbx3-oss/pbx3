<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\EdgePairHealthStore;
use Pbx3\Gatekeeper\EdgePairStore;
use Pbx3\Gatekeeper\Mailer;
use Pbx3\Gatekeeper\NotifyDispatcher;
use Pbx3\Gatekeeper\UserStore;

final class EdgePairStoreTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-edge-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        UserStore::resetForTests();
        $this->seedFoLab();
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

    private function seedFoLab(): void
    {
        EdgePairStore::create([
            'id' => EdgePairStore::FO_LAB_ID,
            'label' => 'FO lab pair',
            'fqdn' => 'sbcfo.pbx3.com',
            'eip' => '98.82.58.59',
            'allocation_id' => 'eipalloc-020e72437124c600e',
            'member_a_instance_id' => 'i-05b30224300cc8812',
            'member_b_instance_id' => 'i-00f85b1c3f18c434e',
            'active_member' => 'a',
            'mode' => 'managed',
        ]);
    }

    public function test_seed_fo_lab_and_patch_mode(): void
    {
        $list = EdgePairStore::list();
        $this->assertNotEmpty($list);
        $fo = EdgePairStore::get(EdgePairStore::FO_LAB_ID);
        $this->assertNotNull($fo);
        $this->assertSame('sbcfo.pbx3.com', $fo['fqdn']);
        $this->assertSame('managed', $fo['mode']);
        $this->assertSame('a', $fo['active_member']);

        $patched = EdgePairStore::patch(EdgePairStore::FO_LAB_ID, [
            'mode' => 'auto',
            'active_member' => 'b',
        ]);
        $this->assertSame('auto', $patched['mode']);
        $this->assertSame('b', $patched['active_member']);
    }

    public function test_health_hysteresis_and_edge_notify(): void
    {
        $admin = UserStore::createUser('edge-ops@example.com', 'GimmeTheFleet', 'Ops');
        UserStore::updateUser((int) $admin['id'], ['notify_failures' => true]);

        $this->assertNull(EdgePairHealthStore::recordProbe('fo-lab', false));
        $this->assertSame('down', EdgePairHealthStore::recordProbe('fo-lab', false));
        $this->assertSame('cleared', EdgePairHealthStore::recordProbe('fo-lab', true));

        $sent = [];
        $mailer = new class($sent) implements Mailer {
            /** @param list<array{to:list<string>,subject:string,body:string}> $sent */
            public function __construct(private array &$sent)
            {
            }

            public function send(array $to, string $subject, string $bodyText): void
            {
                $this->sent[] = ['to' => $to, 'subject' => $subject, 'body' => $bodyText];
            }
        };

        $pair = EdgePairStore::get(EdgePairStore::FO_LAB_ID);
        $this->assertNotNull($pair);
        EdgePairHealthStore::recordProbe('fo-lab', false);
        EdgePairHealthStore::recordProbe('fo-lab', false);

        $dispatcher = new NotifyDispatcher($mailer);
        $dispatcher->notifyEdgeReachability($pair, 'down');
        $this->assertCount(1, $sent);
        $this->assertStringContainsString('Edge down', $sent[0]['subject']);
        $this->assertStringContainsString('sbcfo.pbx3.com', $sent[0]['body']);
    }

    public function test_create_pair(): void
    {
        EdgePairStore::delete(EdgePairStore::FO_LAB_ID);

        $created = EdgePairStore::create([
            'id' => 'live-lab',
            'label' => 'Live lab',
            'fqdn' => 'sbc.pbx3.com',
            'eip' => '1.2.3.4',
            'allocation_id' => 'eipalloc-abc123',
            'member_a_instance_id' => 'i-aaa',
            'member_b_instance_id' => 'i-bbb',
            'active_member' => 'a',
            'mode' => 'managed',
        ]);
        $this->assertSame('live-lab', $created['id']);
        $this->assertSame('sbc.pbx3.com', $created['fqdn']);
        $this->assertSame('managed', $created['mode']);

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('an edge pair already exists');
        EdgePairStore::create([
            'id' => 'second',
            'label' => 'Second',
            'fqdn' => 'sbc2.pbx3.com',
            'eip' => '5.6.7.8',
            'allocation_id' => 'eipalloc-def456',
            'member_a_instance_id' => 'i-ccc',
            'member_b_instance_id' => 'i-ddd',
        ]);
    }

    public function test_delete_pair_removes_health_and_stays_gone(): void
    {
        EdgePairHealthStore::recordProbe(EdgePairStore::FO_LAB_ID, true, 12);
        $this->assertNotNull(EdgePairHealthStore::get(EdgePairStore::FO_LAB_ID));

        EdgePairStore::delete(EdgePairStore::FO_LAB_ID);
        $this->assertNull(EdgePairStore::get(EdgePairStore::FO_LAB_ID));
        $this->assertNull(EdgePairHealthStore::get(EdgePairStore::FO_LAB_ID));
        $this->assertSame([], EdgePairStore::list());
    }
}
