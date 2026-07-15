<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\Auth;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\UserStore;

final class FleetAbilitiesTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-abilities-'.bin2hex(random_bytes(4)).'.sqlite';
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

    public function test_login_returns_abilities_and_expand_fleet_admin(): void
    {
        UserStore::createUser('fleet@example.com', 'GimmeTheFleet', 'Fleet');

        $session = UserStore::login('fleet@example.com', 'GimmeTheFleet', 3600);
        $this->assertSame([FleetAbilities::ADMIN], $session['user']['abilities']);
        $this->assertSame(FleetAbilities::ALL, $session['abilities']);
    }

    public function test_read_only_user_denied_instances_ability(): void
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

        $this->assertTrue(Auth::can(FleetAbilities::READ));
        $this->assertFalse(Auth::can(FleetAbilities::INSTANCES));

        $this->expectException(\RuntimeException::class);
        $this->expectExceptionCode(403);
        Auth::requireAbility(FleetAbilities::INSTANCES);
    }

    public function test_fleet_admin_grants_all_abilities(): void
    {
        UserStore::createUser('admin@example.com', 'GimmeTheFleet', 'Admin', [FleetAbilities::ADMIN]);
        $session = UserStore::login('admin@example.com', 'GimmeTheFleet', 3600);

        $_SERVER['HTTP_AUTHORIZATION'] = 'Bearer '.$session['token'];
        Auth::requireBearer();

        Auth::requireAbility(FleetAbilities::READ);
        Auth::requireAbility(FleetAbilities::INSTANCES);
        Auth::requireAbility(FleetAbilities::MOVES);
        Auth::requireAbility(FleetAbilities::EDGE);
        Auth::requireAbility(FleetAbilities::ADMIN);
        $this->assertSame(FleetAbilities::ALL, Auth::effectiveAbilities());
    }

    public function test_set_abilities_updates_token_session_user(): void
    {
        $user = UserStore::createUser('ops@example.com', 'GimmeTheFleet', 'Ops', [FleetAbilities::READ]);
        UserStore::setAbilities((int) $user['id'], [FleetAbilities::READ, FleetAbilities::MOVES]);

        $session = UserStore::login('ops@example.com', 'GimmeTheFleet', 3600);
        $this->assertSame(
            [FleetAbilities::READ, FleetAbilities::MOVES],
            $session['user']['abilities']
        );
    }

    public function test_normalize_filters_unknown(): void
    {
        $this->assertSame(
            [FleetAbilities::READ],
            FleetAbilities::normalize(['fleet_read', 'not_a_real_ability', 12])
        );
    }
}
