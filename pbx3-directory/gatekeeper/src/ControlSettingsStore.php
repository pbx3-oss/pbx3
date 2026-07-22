<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/**
 * Control-plane settings in SQLite (fleet_admin editable).
 * SBC admin API URL: DB overrides env when set.
 */
final class ControlSettingsStore
{
    public const KEY_SBC_ADMIN_API_URL = 'sbc_admin_api_url';

    public static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS control_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT
);
SQL);
    }

    public static function get(string $key): ?string
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare('SELECT value FROM control_settings WHERE key = ? LIMIT 1');
        $st->execute([trim($key)]);
        $row = $st->fetch(PDO::FETCH_ASSOC);
        if (! is_array($row)) {
            return null;
        }
        $v = trim((string) $row['value']);

        return $v === '' ? null : $v;
    }

    public static function set(string $key, string $value): void
    {
        $key = trim($key);
        if ($key === '') {
            throw new \InvalidArgumentException('key required');
        }
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare(<<<'SQL'
INSERT INTO control_settings (key, value, updated_at) VALUES (?, ?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
SQL);
        $st->execute([$key, trim($value), gmdate('c')]);
    }

    /** Effective URL: SQLite override, else PBX3_SBC_ADMIN_API_URL env. */
    public static function sbcAdminApiUrl(): string
    {
        $fromDb = self::get(self::KEY_SBC_ADMIN_API_URL);
        if ($fromDb !== null) {
            return rtrim($fromDb, '/');
        }

        return rtrim((string) (getenv('PBX3_SBC_ADMIN_API_URL') ?: ''), '/');
    }

    /**
     * @return array{
     *   sbc_admin_api_url: string,
     *   sbc_admin_api_url_source: 'db'|'env'|'unset',
     *   sbc_admin_api_url_env: string
     * }
     */
    public static function edgeSettingsPublic(): array
    {
        $env = rtrim((string) (getenv('PBX3_SBC_ADMIN_API_URL') ?: ''), '/');
        $db = self::get(self::KEY_SBC_ADMIN_API_URL);
        if ($db !== null) {
            return [
                'sbc_admin_api_url' => rtrim($db, '/'),
                'sbc_admin_api_url_source' => 'db',
                'sbc_admin_api_url_env' => $env,
            ];
        }
        if ($env !== '') {
            return [
                'sbc_admin_api_url' => $env,
                'sbc_admin_api_url_source' => 'env',
                'sbc_admin_api_url_env' => $env,
            ];
        }

        return [
            'sbc_admin_api_url' => '',
            'sbc_admin_api_url_source' => 'unset',
            'sbc_admin_api_url_env' => '',
        ];
    }

    /**
     * @param  array<string, mixed>  $patch
     * @return array{sbc_admin_api_url: string, sbc_admin_api_url_source: string, sbc_admin_api_url_env: string}
     */
    public static function patchEdgeSettings(array $patch): array
    {
        if (array_key_exists('sbc_admin_api_url', $patch)) {
            $url = trim((string) $patch['sbc_admin_api_url']);
            if ($url === '') {
                // Clear DB override → fall back to env
                $pdo = UserStore::pdo();
                self::migrate($pdo);
                $st = $pdo->prepare('DELETE FROM control_settings WHERE key = ?');
                $st->execute([self::KEY_SBC_ADMIN_API_URL]);
            } else {
                if (! preg_match('#^https?://#i', $url)) {
                    throw new \InvalidArgumentException('sbc_admin_api_url must start with http:// or https://');
                }
                self::set(self::KEY_SBC_ADMIN_API_URL, rtrim($url, '/'));
            }
        }

        return self::edgeSettingsPublic();
    }
}
