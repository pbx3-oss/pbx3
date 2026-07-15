<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\UserStore;

final class FleetUserManageTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-users-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        UserStore::resetForTests();
        Auth::resetForTests();
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
        unset($_SERVER['HTTP_AUTHORIZATION'], $_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    }

    public function test_list_create_update_and_revoke_sessions(): void
    {
        $admin = UserStore::createUser('admin@example.com', 'GimmeTheFleet', 'Admin');
        $reader = UserStore::createUser(
            'reader@example.com',
            'GimmeTheFleet',
            'Reader',
            [FleetAbilities::READ]
        );

        $listed = UserStore::listUsers();
        $this->assertCount(2, $listed);
        $this->assertSame('admin@example.com', $listed[0]['email']);

        $session = UserStore::login('reader@example.com', 'GimmeTheFleet', 3600);
        $this->assertNotNull(UserStore::userForToken($session['token']));

        $updated = UserStore::updateUser((int) $reader['id'], [
            'name' => 'Read Only',
            'abilities' => [FleetAbilities::READ, FleetAbilities::MOVES],
        ]);
        $this->assertSame('Read Only', $updated['name']);
        $this->assertSame(
            [FleetAbilities::READ, FleetAbilities::MOVES],
            $updated['abilities']
        );

        $revoked = UserStore::revokeAllTokensForUser((int) $reader['id']);
        $this->assertSame(1, $revoked);
        $this->assertNull(UserStore::userForToken($session['token']));
        $this->assertSame(0, UserStore::findById((int) $reader['id'])['session_count']);
        $this->assertSame('admin@example.com', $admin['email']);
    }

    public function test_disable_blocks_login_and_kills_session(): void
    {
        UserStore::createUser('admin@example.com', 'GimmeTheFleet', 'Admin');
        $ops = UserStore::createUser('ops@example.com', 'GimmeTheFleet', 'Ops', [FleetAbilities::READ]);
        $session = UserStore::login('ops@example.com', 'GimmeTheFleet', 3600);

        $disabled = UserStore::disableUser((int) $ops['id'], null);
        $this->assertNotNull($disabled['disabled_at']);
        $this->assertNull(UserStore::userForToken($session['token']));

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(403);
        UserStore::login('ops@example.com', 'GimmeTheFleet');
    }

    public function test_enable_restores_login(): void
    {
        UserStore::createUser('admin@example.com', 'GimmeTheFleet');
        $ops = UserStore::createUser('ops@example.com', 'GimmeTheFleet', 'Ops', [FleetAbilities::READ]);
        UserStore::disableUser((int) $ops['id']);
        UserStore::enableUser((int) $ops['id']);

        $session = UserStore::login('ops@example.com', 'GimmeTheFleet', 3600);
        $this->assertSame('ops@example.com', $session['user']['email']);
    }

    public function test_cannot_disable_self(): void
    {
        $admin = UserStore::createUser('admin@example.com', 'GimmeTheFleet');
        UserStore::createUser('other@example.com', 'GimmeTheFleet');

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(422);
        UserStore::disableUser((int) $admin['id'], (int) $admin['id']);
    }

    public function test_cannot_disable_last_fleet_admin(): void
    {
        $admin = UserStore::createUser('admin@example.com', 'GimmeTheFleet');

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(422);
        UserStore::disableUser((int) $admin['id']);
    }

    public function test_cannot_demote_last_fleet_admin(): void
    {
        $admin = UserStore::createUser('admin@example.com', 'GimmeTheFleet');

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(422);
        UserStore::updateUser((int) $admin['id'], ['abilities' => [FleetAbilities::READ]]);
    }

    public function test_fleet_users_require_admin_ability(): void
    {
        UserStore::createUser(
            'reader@example.com',
            'GimmeTheFleet',
            'Reader',
            [FleetAbilities::READ]
        );
        $session = UserStore::login('reader@example.com', 'GimmeTheFleet', 3600);
        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer '.$session['token'];
        Auth::requireBearer();

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(403);
        Auth::requireAbility(FleetAbilities::ADMIN);
    }

    public function test_duplicate_email_rejected(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet');

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(409);
        UserStore::createUser('Fleet@example.com', 'GimmeTheFleet');
    }
}
