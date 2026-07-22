<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\ControlSettingsStore;
use Pbx3\Gatekeeper\UserStore;

final class ControlSettingsStoreTest extends TestCase
{
    private string $dbPath;

    protected function setUp(): void
    {
        $this->dbPath = sys_get_temp_dir().'/pbx3-gatekeeper-settings-'.bin2hex(random_bytes(4)).'.sqlite';
        putenv('GATEKEEPER_AUTH_DB='.$this->dbPath);
        $_ENV['GATEKEEPER_AUTH_DB'] = $this->dbPath;
        putenv('PBX3_SBC_ADMIN_API_URL');
        unset($_ENV['PBX3_SBC_ADMIN_API_URL']);
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
        putenv('PBX3_SBC_ADMIN_API_URL');
        unset($_ENV['PBX3_SBC_ADMIN_API_URL']);
    }

    public function test_env_then_db_override_then_clear(): void
    {
        putenv('PBX3_SBC_ADMIN_API_URL=https://env.example/api/');
        $_ENV['PBX3_SBC_ADMIN_API_URL'] = 'https://env.example/api/';

        $pub = ControlSettingsStore::edgeSettingsPublic();
        $this->assertSame('env', $pub['sbc_admin_api_url_source']);
        $this->assertSame('https://env.example/api', $pub['sbc_admin_api_url']);
        $this->assertSame('https://env.example/api', ControlSettingsStore::sbcAdminApiUrl());

        $pub = ControlSettingsStore::patchEdgeSettings([
            'sbc_admin_api_url' => 'https://db.example/api/',
        ]);
        $this->assertSame('db', $pub['sbc_admin_api_url_source']);
        $this->assertSame('https://db.example/api', ControlSettingsStore::sbcAdminApiUrl());

        $pub = ControlSettingsStore::patchEdgeSettings(['sbc_admin_api_url' => '']);
        $this->assertSame('env', $pub['sbc_admin_api_url_source']);
        $this->assertSame('https://env.example/api', ControlSettingsStore::sbcAdminApiUrl());
    }

    public function test_rejects_non_http_url(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        ControlSettingsStore::patchEdgeSettings(['sbc_admin_api_url' => 'ftp://nope']);
    }
}
