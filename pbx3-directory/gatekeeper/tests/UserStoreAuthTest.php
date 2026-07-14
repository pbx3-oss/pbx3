<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\UserStore;

final class UserStoreAuthTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-auth-test-'.bin2hex(random_bytes(4)).'.sqlite';
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

    public function test_login_me_and_revoke_session_token(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet', 'Fleet');

        $session = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertNotSame('', $session['token']);
        $this->assertSame('fleet@example.com', $session['user']['email']);

        $me = UserStore::userForToken($session['token']);
        $this->assertNotNull($me);
        $this->assertSame('fleet@example.com', $me['email']);

        UserStore::revokeToken($session['token']);
        $this->assertNull(UserStore::userForToken($session['token']));
    }

    public function test_bad_password_rejected(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet');

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(401);
        UserStore::login('fleet@example.com', 'wrong-password');
    }

    public function test_short_password_rejected_on_create(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        UserStore::createUser('fleet@example.com', 'short');
    }
}
