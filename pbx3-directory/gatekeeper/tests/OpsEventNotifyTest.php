<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\Mailer;
use Pbx3\Gatekeeper\NotifyDispatcher;
use Pbx3\Gatekeeper\OpsEventThrottle;
use Pbx3\Gatekeeper\UserStore;

final class OpsEventNotifyTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-ops-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        putenv('GATEKEEPER_OPS_NOTIFY_EMAIL=ops@example.com');
        $_ENV['GATEKEEPER_OPS_NOTIFY_EMAIL'] = 'ops@example.com';
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
        putenv('GATEKEEPER_OPS_NOTIFY_EMAIL');
        unset($_ENV['GATEKEEPER_OPS_NOTIFY_EMAIL']);
    }

    public function test_misconfig_register_mail(): void
    {
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

        (new NotifyDispatcher($mailer))->notifyMisconfigRegister([
            'instance_id' => 'abc',
            'instance_label' => 'bzy54n',
            'fqdn' => 'bzy54n.pbx3.com',
            'extension' => '1102',
            'source_ip' => '203.0.113.50',
            'count' => 5,
            'window_seconds' => 600,
            'sample' => 'Wrong password',
        ]);

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('1102', $sent[0]['subject']);
        $this->assertStringContainsString('203.0.113.50', $sent[0]['body']);
        $this->assertStringContainsString('Do not ban', $sent[0]['body']);
    }

    public function test_ops_event_throttle(): void
    {
        $this->assertTrue(OpsEventThrottle::allow('k1', 60));
        $this->assertFalse(OpsEventThrottle::allow('k1', 60));
        $this->assertTrue(OpsEventThrottle::allow('k2', 60));
    }
}
