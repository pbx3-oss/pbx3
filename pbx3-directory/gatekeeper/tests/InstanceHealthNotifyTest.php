<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceHealthStore;
use Pbx3\Gatekeeper\Mailer;
use Pbx3\Gatekeeper\NotifyDispatcher;
use Pbx3\Gatekeeper\UserStore;

final class InstanceHealthNotifyTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-health-'.bin2hex(random_bytes(4)).'.sqlite';
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

    public function test_hysteresis_down_then_cleared(): void
    {
        $this->assertNull(InstanceHealthStore::recordProbe('node1', false));
        $this->assertSame('down', InstanceHealthStore::recordProbe('node1', false));
        $this->assertNull(InstanceHealthStore::recordProbe('node1', false));
        $this->assertSame('cleared', InstanceHealthStore::recordProbe('node1', true));
        $this->assertNull(InstanceHealthStore::recordProbe('node1', true));
    }

    public function test_success_bootstrap_does_not_notify(): void
    {
        $this->assertNull(InstanceHealthStore::recordProbe('node2', true));
        $row = InstanceHealthStore::get('node2');
        $this->assertTrue($row['reachable']);
        $this->assertNull($row['last_notified_reachable']);
    }

    public function test_notify_dispatcher_uses_subscribers_and_mailer(): void
    {
        $admin = UserStore::createUser('ops@example.com', 'GimmeTheFleet', 'Ops');
        UserStore::updateUser((int) $admin['id'], ['notify_failures' => true]);
        UserStore::createUser('quiet@example.com', 'GimmeTheFleet', 'Quiet');

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

        InstanceHealthStore::recordProbe('abc', false);
        InstanceHealthStore::recordProbe('abc', false);

        $dispatcher = new NotifyDispatcher($mailer);
        $dispatcher->notifyInstanceReachability(
            ['id' => 'abc', 'label' => 'golden', 'fqdn' => '08jzwn.pbx3.com'],
            'down'
        );

        $this->assertCount(1, $sent);
        $this->assertSame(['ops@example.com'], $sent[0]['to']);
        $this->assertStringContainsString('Instance down', $sent[0]['subject']);
        $this->assertStringContainsString('golden', $sent[0]['body']);
    }

    public function test_notify_failures_flag_on_user(): void
    {
        $u = UserStore::createUser('a@example.com', 'GimmeTheFleet');
        $this->assertFalse($u['notify_failures']);
        $updated = UserStore::updateUser((int) $u['id'], ['notify_failures' => true]);
        $this->assertTrue($updated['notify_failures']);
        $this->assertSame(['a@example.com'], UserStore::notifyFailureEmails());
    }
}
