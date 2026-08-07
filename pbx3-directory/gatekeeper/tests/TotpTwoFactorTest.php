<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\TotpService;
use Pbx3\Gatekeeper\UserStore;
use PragmaRX\Google2FA\Google2FA;

final class TotpTwoFactorTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-totp-test-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        putenv('GATEKEEPER_TOTP_KEY=test-totp-key');
        $_ENV['GATEKEEPER_TOTP_KEY'] = 'test-totp-key';
        UserStore::resetForTests();
        Auth::resetForTests();
    }

    protected function tearDown(): void
    {
        UserStore::resetForTests();
        Auth::resetForTests();
        if (is_file($this->dbPath)) {
            @unlink($this->dbPath);
        }
        putenv('GATEKEEPER_AUTH_DB');
        unset($_ENV['GATEKEEPER_AUTH_DB']);
        putenv('GATEKEEPER_TOTP_KEY');
        unset($_ENV['GATEKEEPER_TOTP_KEY']);
    }

    public function test_login_without_2fa_unchanged(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet', 'Fleet');
        $session = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertArrayHasKey('token', $session);
        $this->assertArrayNotHasKey('requires_2fa', $session);
        $this->assertFalse($session['user']['two_factor_enabled']);
    }

    public function test_login_with_2fa_requires_challenge_then_verify(): void
    {
        $user = UserStore::createUser('fleet@example.com', 'GimmeTheFleet', 'Fleet');
        $g2fa = new Google2FA;
        $setup = UserStore::setupTwoFactor((int) $user['id'], 'GimmeTheFleet');
        $plain = $setup['secret'];
        UserStore::confirmTwoFactor((int) $user['id'], $g2fa->getCurrentOtp($plain));

        $login = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertTrue($login['requires_2fa'] ?? false);
        $this->assertArrayHasKey('challenge_id', $login);
        $this->assertArrayNotHasKey('token', $login);

        $bad = null;
        try {
            UserStore::verifyTwoFactor($login['challenge_id'], '000000', 3600);
        } catch (\RuntimeException $e) {
            $bad = $e;
        }
        $this->assertInstanceOf(\RuntimeException::class, $bad);
        $this->assertSame(401, $bad->getCode());

        $login2 = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $session = UserStore::verifyTwoFactor($login2['challenge_id'], $g2fa->getCurrentOtp($plain), 3600);
        $this->assertNotSame('', $session['token']);
        $this->assertTrue($session['user']['two_factor_enabled']);
    }

    public function test_recovery_code_single_use(): void
    {
        $user = UserStore::createUser('fleet@example.com', 'GimmeTheFleet');
        $g2fa = new Google2FA;
        $setup = UserStore::setupTwoFactor((int) $user['id'], 'GimmeTheFleet');
        $confirm = UserStore::confirmTwoFactor((int) $user['id'], $g2fa->getCurrentOtp($setup['secret']));
        $recovery = $confirm['recovery_codes'][0];

        $login = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $session = UserStore::verifyTwoFactor($login['challenge_id'], $recovery, 3600);
        $this->assertNotSame('', $session['token']);

        $login2 = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(401);
        UserStore::verifyTwoFactor($login2['challenge_id'], $recovery, 3600);
    }

    public function test_disable_and_admin_clear(): void
    {
        $user = UserStore::createUser('fleet@example.com', 'GimmeTheFleet');
        $g2fa = new Google2FA;
        $setup = UserStore::setupTwoFactor((int) $user['id'], 'GimmeTheFleet');
        UserStore::confirmTwoFactor((int) $user['id'], $g2fa->getCurrentOtp($setup['secret']));

        $login = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertTrue($login['requires_2fa'] ?? false);

        $code = $g2fa->getCurrentOtp($setup['secret']);
        UserStore::disableTwoFactor((int) $user['id'], 'GimmeTheFleet', $code);

        $session = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertArrayHasKey('token', $session);

        $setup2 = UserStore::setupTwoFactor((int) $user['id'], 'GimmeTheFleet');
        UserStore::confirmTwoFactor((int) $user['id'], $g2fa->getCurrentOtp($setup2['secret']));
        $challengeLogin = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertTrue($challengeLogin['requires_2fa'] ?? false);
        $cleared = UserStore::clearTwoFactorForUser((int) $user['id']);
        $this->assertFalse($cleared['two_factor_enabled']);
        $again = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertArrayHasKey('token', $again);
    }

    public function test_break_glass_unaffected(): void
    {
        putenv('GATEKEEPER_API_TOKEN=break-glass-test-token');
        $_ENV['GATEKEEPER_API_TOKEN'] = 'break-glass-test-token';
        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer break-glass-test-token';
        Auth::requireBearer();
        $this->assertTrue(Auth::isBreakGlass());
        $this->assertTrue(Auth::can('fleet_admin'));
        putenv('GATEKEEPER_API_TOKEN');
        unset($_ENV['GATEKEEPER_API_TOKEN']);
        unset($_SERVER['HTTP_AUTHORIZATION']);
    }

    public function test_issuer_default(): void
    {
        $totp = new TotpService;
        $this->assertSame('Aelintra Fleet', $totp->issuer());
    }
}
