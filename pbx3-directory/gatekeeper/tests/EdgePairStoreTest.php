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
}
