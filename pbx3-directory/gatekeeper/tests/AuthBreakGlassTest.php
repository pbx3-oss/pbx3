<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\UserStore;

final class AuthBreakGlassTest extends TestCase
{
    private string $dbPath;

    private string $prevToken;

    private bool $hadToken;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-auth-bg-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        UserStore::resetForTests();
        Auth::resetForTests();

        $this->hadToken = getenv('GATEKEEPER_API_TOKEN') !== false;
        $this->prevToken = $this->hadToken ? (string) getenv('GATEKEEPER_API_TOKEN') : '';
        putenv('GATEKEEPER_API_TOKEN=break-glass-secret-token');
        $_ENV['GATEKEEPER_API_TOKEN'] = 'break-glass-secret-token';
        unset($_SERVER['HTTP_AUTHORIZATION'], $_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    }

    protected function tearDown(): void
    {
        Auth::resetForTests();
        UserStore::resetForTests();
        if (is_file($this->dbPath)) {
            @unlink($this->dbPath);
        }
        putenv('GATEKEEPER_AUTH_DB');
        unset($_ENV['GATEKEEPER_AUTH_DB']);

        if ($this->hadToken) {
            putenv('GATEKEEPER_API_TOKEN='.$this->prevToken);
            $_ENV['GATEKEEPER_API_TOKEN'] = $this->prevToken;
        } else {
            putenv('GATEKEEPER_API_TOKEN');
            unset($_ENV['GATEKEEPER_API_TOKEN']);
        }
        unset($_SERVER['HTTP_AUTHORIZATION'], $_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    }

    public function test_env_token_authenticates_as_break_glass(): void
    {
        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer break-glass-secret-token';
        Auth::requireBearer();

        $this->assertTrue(Auth::isBreakGlass());
        $this->assertSame('break-glass@local', Auth::user()['email'] ?? null);
    }

    public function test_session_token_authenticates_without_break_glass(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet');
        $session = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);

        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer '.$session['token'];
        Auth::requireBearer();

        $this->assertFalse(Auth::isBreakGlass());
        $this->assertSame('fleet@example.com', Auth::user()['email'] ?? null);
    }

    public function test_wrong_bearer_rejected(): void
    {
        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer not-the-token';
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(401);
        Auth::requireBearer();
    }

    public function test_missing_bearer_rejected(): void
    {
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(401);
        Auth::requireBearer();
    }

    public function test_break_glass_preferred_over_session_when_env_matches(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet');
        UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);

        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer break-glass-secret-token';
        Auth::requireBearer();

        $this->assertTrue(Auth::isBreakGlass());
        $this->assertSame('break-glass@local', Auth::user()['email'] ?? null);
    }
}
