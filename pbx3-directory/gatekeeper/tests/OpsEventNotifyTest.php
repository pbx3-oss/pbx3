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
            'extension' => '1003',
            'endpoint_uid' => '8pmfxd',
            'endpoint_name' => 'JohnKnox',
            'source_ip' => '203.0.113.50',
            'count' => 5,
            'window_seconds' => 600,
            'sample' => 'Wrong password',
        ]);

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('1003', $sent[0]['subject']);
        $this->assertStringContainsString('1003 (8pmfxd) — JohnKnox', $sent[0]['body']);
        $this->assertStringContainsString('203.0.113.50', $sent[0]['body']);
        $this->assertStringContainsString('Do not ban', $sent[0]['body']);
    }

    public function test_move_job_failed_mail(): void
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

        putenv('GATEKEEPER_FLEET_UI_URL=https://spa.example');
        $_ENV['GATEKEEPER_FLEET_UI_URL'] = 'https://spa.example';

        (new NotifyDispatcher($mailer))->notifyMoveJobTerminal([
            'id' => 'tmj_abc',
            'tenant_shortuid' => 'affcot',
            'tenant_fqdn' => 'affcot.pbx3.com',
            'source_instance_id' => '08jzwn',
            'dest_instance_id' => 'bzy54n',
            'error' => 'export boom',
            'phases' => [
                'preflight' => ['status' => 'ok'],
                'exporting' => ['status' => 'failed', 'message' => 'export boom'],
            ],
        ], 'failed');

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('Move job failed', $sent[0]['subject']);
        $this->assertStringContainsString('affcot', $sent[0]['body']);
        $this->assertStringContainsString('Failed phase: exporting', $sent[0]['body']);
        $this->assertStringContainsString('/fleet/jobs', $sent[0]['body']);

        putenv('GATEKEEPER_FLEET_UI_URL');
        unset($_ENV['GATEKEEPER_FLEET_UI_URL']);
    }

    public function test_fail2ban_ban_mail(): void
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

        (new NotifyDispatcher($mailer))->notifyFail2banBan([
            'source_ip' => '198.51.100.9',
            'jail' => 'opensips-brute-force',
            'sbc_fqdn' => 'sbc.pbx3.com',
            'currently_banned' => 3,
        ]);

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('198.51.100.9', $sent[0]['subject']);
        $this->assertStringContainsString('sbc.pbx3.com', $sent[0]['body']);
        $this->assertStringContainsString('opensips-brute-force', $sent[0]['body']);
    }

    public function test_egress_unavail_mail(): void
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

        $notify = new NotifyDispatcher($mailer);
        $notify->notifyEgressQualify([
            'instance_id' => 'abc',
            'instance_label' => '08jzwn',
            'fqdn' => '08jzwn.pbx3.com',
            'egress_trunk' => 'Egress',
            'consecutive_unavail' => 2,
        ], 'down');
        $notify->notifyEgressQualify([
            'instance_id' => 'abc',
            'instance_label' => '08jzwn',
            'fqdn' => '08jzwn.pbx3.com',
            'egress_trunk' => 'Egress',
            'rtt_ms' => 7,
        ], 'cleared');

        $this->assertCount(2, $sent);
        $this->assertStringContainsString('Egress Unavail', $sent[0]['subject']);
        $this->assertStringContainsString('08jzwn', $sent[0]['body']);
        $this->assertStringContainsString('Egress cleared', $sent[1]['subject']);
        $this->assertStringContainsString('7 ms', $sent[1]['body']);
    }

    public function test_velocity_irsf_mail(): void
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

        $notify = new NotifyDispatcher($mailer);
        $notify->notifyVelocityIrsf([
            'instance_id' => 'abc',
            'instance_label' => '08jzwn',
            'fqdn' => '08jzwn.pbx3.com',
            'extension' => '1001',
            'extension_shortuid' => 'cccc3333',
            'accountcode' => 'labtenant',
            'count' => 12,
            'window_minutes' => 5,
            'masked_prefixes' => ['0900***'],
            'first_calldate' => '2026-07-24 12:00:00',
            'last_calldate' => '2026-07-24 12:02:00',
            'auto_block' => true,
            'forwards_cleared' => true,
            'hung_up_count' => 2,
            'attribution_reason' => 'channel_shortuid',
        ], 'down');
        $notify->notifyVelocityIrsf([
            'instance_id' => 'abc',
            'instance_label' => '08jzwn',
            'fqdn' => '08jzwn.pbx3.com',
            'extension' => '1001',
            'count' => 0,
            'window_minutes' => 5,
        ], 'cleared');

        $this->assertCount(2, $sent);
        $this->assertStringContainsString('Velocity IRSF', $sent[0]['subject']);
        $this->assertStringContainsString('1001', $sent[0]['subject']);
        $this->assertStringContainsString('0900***', $sent[0]['body']);
        $this->assertStringNotContainsString('09001234567', $sent[0]['body']);
        $this->assertStringContainsString('labtenant', $sent[0]['body']);
        $this->assertStringContainsString('active=NO', $sent[0]['body']);
        $this->assertStringContainsString('Live channels hung up: 2', $sent[0]['body']);
        $this->assertStringContainsString('cleared', $sent[1]['subject']);
    }

    public function test_velocity_off_hours_mail(): void
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

        $notify = new NotifyDispatcher($mailer);
        $notify->notifyVelocityOffHours([
            'instance_id' => 'abc',
            'instance_label' => '08jzwn',
            'fqdn' => '08jzwn.pbx3.com',
            'extension' => '1001',
            'count' => 20,
            'window_minutes' => 60,
            'masked_prefixes' => ['0900***'],
            'auto_block' => false,
        ], 'down');

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('Velocity off-hours', $sent[0]['subject']);
        $this->assertStringContainsString('off-hours', $sent[0]['body']);
        $this->assertStringContainsString('0900***', $sent[0]['body']);
    }

    public function test_ops_event_throttle(): void
    {
        $this->assertTrue(OpsEventThrottle::allow('k1', 60));
        $this->assertFalse(OpsEventThrottle::allow('k1', 60));
        $this->assertTrue(OpsEventThrottle::allow('k2', 60));
    }
}
