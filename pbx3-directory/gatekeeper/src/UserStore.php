<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/** SQLite users + opaque API tokens for fleet operator login. */
final class UserStore
{
    private static ?PDO $pdo = null;

    public static function dbPath(): string
    {
        $path = getenv('GATEKEEPER_AUTH_DB') ?: '';
        if ($path !== '') {
            return $path;
        }

        return dirname(__DIR__).'/data/auth.sqlite';
    }

    public static function pdo(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }

        $path = self::dbPath();
        $dir = dirname($path);
        if (! is_dir($dir) && ! mkdir($dir, 0750, true) && ! is_dir($dir)) {
            throw new \RuntimeException("Cannot create auth DB directory: {$dir}", 500);
        }

        $pdo = new PDO('sqlite:'.$path, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        $pdo->exec('PRAGMA foreign_keys = ON');
        self::migrate($pdo);
        self::$pdo = $pdo;

        return $pdo;
    }

    private static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    name TEXT NOT NULL DEFAULT '',
    password_hash TEXT NOT NULL,
    abilities TEXT NOT NULL DEFAULT '["fleet_admin"]',
    notify_failures INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    disabled_at TEXT
);
CREATE TABLE IF NOT EXISTS api_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL DEFAULT 'session',
    expires_at TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS api_tokens_user_id ON api_tokens(user_id);
SQL);

        $cols = $pdo->query('PRAGMA table_info(users)')->fetchAll();
        $names = array_map(static fn (array $c): string => (string) $c['name'], $cols);
        if (! in_array('abilities', $names, true)) {
            $pdo->exec('ALTER TABLE users ADD COLUMN abilities TEXT NOT NULL DEFAULT \'["fleet_admin"]\'');
        }
        if (! in_array('disabled_at', $names, true)) {
            $pdo->exec('ALTER TABLE users ADD COLUMN disabled_at TEXT');
        }
        if (! in_array('notify_failures', $names, true)) {
            $pdo->exec('ALTER TABLE users ADD COLUMN notify_failures INTEGER NOT NULL DEFAULT 0');
        }
        InstanceHealthStore::migrate($pdo);
        OpsEventThrottle::migrate($pdo);
    }

    /**
     * @return array{id:int,email:string,name:string,abilities:list<string>,disabled_at:?string,password_hash:string}|null
     */
    public static function findByEmail(string $email): ?array
    {
        $st = self::pdo()->prepare(
            'SELECT id, email, name, password_hash, abilities, disabled_at FROM users WHERE email = ? COLLATE NOCASE LIMIT 1'
        );
        $st->execute([trim($email)]);
        $row = $st->fetch();
        if (! is_array($row)) {
            return null;
        }

        return self::mapUserRow($row, true);
    }

    /**
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,notify_failures:bool,session_count:int}|null
     */
    public static function findById(int $id): ?array
    {
        $st = self::pdo()->prepare(<<<'SQL'
SELECT u.id, u.email, u.name, u.abilities, u.created_at, u.disabled_at, u.notify_failures,
       (SELECT COUNT(*) FROM api_tokens t WHERE t.user_id = u.id) AS session_count
FROM users u
WHERE u.id = ?
LIMIT 1
SQL);
        $st->execute([$id]);
        $row = $st->fetch();
        if (! is_array($row)) {
            return null;
        }

        return self::mapPublicUserRow($row);
    }

    public static function userCount(): int
    {
        return (int) self::pdo()->query('SELECT COUNT(*) FROM users')->fetchColumn();
    }

    /**
     * @return list<array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,notify_failures:bool,session_count:int}>
     */
    public static function listUsers(): array
    {
        $rows = self::pdo()->query(<<<'SQL'
SELECT u.id, u.email, u.name, u.abilities, u.created_at, u.disabled_at, u.notify_failures,
       (SELECT COUNT(*) FROM api_tokens t WHERE t.user_id = u.id) AS session_count
FROM users u
ORDER BY u.email COLLATE NOCASE ASC
SQL)->fetchAll();
        $out = [];
        foreach ($rows as $row) {
            if (is_array($row)) {
                $out[] = self::mapPublicUserRow($row);
            }
        }

        return $out;
    }

    /** Emails of active users subscribed to failure notify. */
    public static function notifyFailureEmails(): array
    {
        $rows = self::pdo()->query(<<<'SQL'
SELECT email FROM users
WHERE disabled_at IS NULL AND notify_failures = 1
ORDER BY email COLLATE NOCASE ASC
SQL)->fetchAll();
        $out = [];
        foreach ($rows as $row) {
            if (! is_array($row)) {
                continue;
            }
            $email = trim((string) ($row['email'] ?? ''));
            if ($email !== '' && filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $out[] = $email;
            }
        }

        return $out;
    }

    /**
     * @param  list<string>|null  $abilities  null = DEFAULT_BOOTSTRAP (fleet_admin)
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,session_count:int}
     */
    public static function createUser(string $email, string $password, string $name = '', ?array $abilities = null): array
    {
        $email = strtolower(trim($email));
        if ($email === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException('Valid email required');
        }
        if (strlen($password) < 10) {
            throw new \InvalidArgumentException('Password must be at least 10 characters');
        }
        $hash = password_hash($password, PASSWORD_DEFAULT);
        if ($hash === false) {
            throw new \RuntimeException('password_hash failed', 500);
        }
        $normalized = FleetAbilities::normalize($abilities ?? FleetAbilities::DEFAULT_BOOTSTRAP);
        if ($normalized === []) {
            throw new \InvalidArgumentException('At least one valid fleet_* ability required');
        }
        $now = gmdate('c');
        $st = self::pdo()->prepare(
            'INSERT INTO users (email, name, password_hash, abilities, created_at) VALUES (?, ?, ?, ?, ?)'
        );
        try {
            $st->execute([
                $email,
                trim($name) !== '' ? trim($name) : $email,
                $hash,
                FleetAbilities::toJson($normalized),
                $now,
            ]);
        } catch (\PDOException $e) {
            if (str_contains($e->getMessage(), 'UNIQUE')) {
                throw new \RuntimeException('Email already registered', 409);
            }
            throw $e;
        }

        $created = self::findById((int) self::pdo()->lastInsertId());
        if ($created === null) {
            throw new \RuntimeException('User create failed', 500);
        }

        return $created;
    }

    /**
     * @param  list<string>  $abilities
     */
    public static function setAbilities(int $userId, array $abilities): void
    {
        self::updateUser($userId, ['abilities' => $abilities]);
    }

    /**
     * @param  array{name?:string,password?:string,abilities?:list<string>,notify_failures?:bool}  $patch
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,notify_failures:bool,session_count:int}
     */
    public static function updateUser(int $userId, array $patch): array
    {
        $existing = self::findById($userId);
        if ($existing === null) {
            throw new \RuntimeException('User not found', 404);
        }

        $name = array_key_exists('name', $patch) ? trim((string) $patch['name']) : $existing['name'];
        if ($name === '') {
            $name = $existing['email'];
        }

        $abilities = $existing['abilities'];
        if (array_key_exists('abilities', $patch)) {
            if (! is_array($patch['abilities'])) {
                throw new \InvalidArgumentException('abilities must be an array');
            }
            $abilities = FleetAbilities::normalize($patch['abilities']);
            if ($abilities === []) {
                throw new \InvalidArgumentException('At least one valid fleet_* ability required');
            }
            self::assertMayDropAdminAbility($userId, $existing['abilities'], $abilities);
        }

        $notifyFailures = $existing['notify_failures'];
        if (array_key_exists('notify_failures', $patch)) {
            $notifyFailures = (bool) $patch['notify_failures'];
        }

        $sets = ['name = ?', 'abilities = ?', 'notify_failures = ?'];
        $params = [$name, FleetAbilities::toJson($abilities), $notifyFailures ? 1 : 0];

        if (array_key_exists('password', $patch) && is_string($patch['password']) && $patch['password'] !== '') {
            if (strlen($patch['password']) < 10) {
                throw new \InvalidArgumentException('Password must be at least 10 characters');
            }
            $hash = password_hash($patch['password'], PASSWORD_DEFAULT);
            if ($hash === false) {
                throw new \RuntimeException('password_hash failed', 500);
            }
            $sets[] = 'password_hash = ?';
            $params[] = $hash;
        }

        $params[] = $userId;
        $sql = 'UPDATE users SET '.implode(', ', $sets).' WHERE id = ?';
        self::pdo()->prepare($sql)->execute($params);

        $updated = self::findById($userId);
        if ($updated === null) {
            throw new \RuntimeException('User not found', 404);
        }

        return $updated;
    }

    /**
     * Soft-disable: blocks login; revokes all sessions.
     *
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,session_count:int}
     */
    public static function disableUser(int $userId, ?int $actorUserId = null): array
    {
        $existing = self::findById($userId);
        if ($existing === null) {
            throw new \RuntimeException('User not found', 404);
        }
        if ($actorUserId !== null && $actorUserId === $userId) {
            throw new \RuntimeException('Cannot disable your own account', 422);
        }
        if ($existing['disabled_at'] !== null) {
            return $existing;
        }
        self::assertMayDisableOrDemoteAdmin($userId, $existing['abilities']);

        $now = gmdate('c');
        self::pdo()->prepare('UPDATE users SET disabled_at = ? WHERE id = ?')->execute([$now, $userId]);
        self::revokeAllTokensForUser($userId);

        $updated = self::findById($userId);
        if ($updated === null) {
            throw new \RuntimeException('User not found', 404);
        }

        return $updated;
    }

    /**
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,session_count:int}
     */
    public static function enableUser(int $userId): array
    {
        $existing = self::findById($userId);
        if ($existing === null) {
            throw new \RuntimeException('User not found', 404);
        }
        if ($existing['disabled_at'] === null) {
            return $existing;
        }
        self::pdo()->prepare('UPDATE users SET disabled_at = NULL WHERE id = ?')->execute([$userId]);

        $updated = self::findById($userId);
        if ($updated === null) {
            throw new \RuntimeException('User not found', 404);
        }

        return $updated;
    }

    public static function revokeAllTokensForUser(int $userId): int
    {
        $st = self::pdo()->prepare('DELETE FROM api_tokens WHERE user_id = ?');
        $st->execute([$userId]);

        return $st->rowCount();
    }

    /**
     * @return array{token:string,token_type:string,user:array{id:int,email:string,name:string,abilities:list<string>},expires_at:?string,abilities:list<string>}
     */
    public static function login(string $email, string $password, int $ttlSeconds = 86400 * 7): array
    {
        $row = self::findByEmail($email);
        if ($row === null || ! password_verify($password, $row['password_hash'])) {
            throw new \RuntimeException('Invalid email or password', 401);
        }
        if ($row['disabled_at'] !== null) {
            throw new \RuntimeException('Account disabled', 403);
        }
        unset($row['password_hash']);

        $plain = bin2hex(random_bytes(32));
        $hash = hash('sha256', $plain);
        $expires = $ttlSeconds > 0 ? gmdate('c', time() + $ttlSeconds) : null;
        $now = gmdate('c');
        $st = self::pdo()->prepare(
            'INSERT INTO api_tokens (user_id, token_hash, label, expires_at, created_at) VALUES (?, ?, ?, ?, ?)'
        );
        $st->execute([(int) $row['id'], $hash, 'session', $expires, $now]);

        return [
            'token' => $plain,
            'token_type' => 'Bearer',
            'expires_at' => $expires,
            'user' => [
                'id' => (int) $row['id'],
                'email' => (string) $row['email'],
                'name' => (string) $row['name'],
                'abilities' => $row['abilities'],
            ],
            'abilities' => FleetAbilities::expand($row['abilities']),
        ];
    }

    /**
     * @return array{id:int,email:string,name:string,abilities:list<string>,token_id:int}|null
     */
    public static function userForToken(string $plainToken): ?array
    {
        $hash = hash('sha256', $plainToken);
        $st = self::pdo()->prepare(<<<'SQL'
SELECT u.id, u.email, u.name, u.abilities, u.disabled_at, t.id AS token_id, t.expires_at
FROM api_tokens t
JOIN users u ON u.id = t.user_id
WHERE t.token_hash = ?
LIMIT 1
SQL);
        $st->execute([$hash]);
        $row = $st->fetch();
        if (! is_array($row)) {
            return null;
        }
        if (! empty($row['disabled_at'])) {
            self::pdo()->prepare('DELETE FROM api_tokens WHERE id = ?')->execute([(int) $row['token_id']]);

            return null;
        }
        if (! empty($row['expires_at']) && strtotime((string) $row['expires_at']) < time()) {
            self::pdo()->prepare('DELETE FROM api_tokens WHERE id = ?')->execute([(int) $row['token_id']]);

            return null;
        }

        $user = self::mapUserRow($row, false);
        $user['token_id'] = (int) $row['token_id'];

        return $user;
    }

    public static function revokeToken(string $plainToken): void
    {
        $hash = hash('sha256', $plainToken);
        self::pdo()->prepare('DELETE FROM api_tokens WHERE token_hash = ?')->execute([$hash]);
    }

    public static function revokeTokenId(int $tokenId): void
    {
        self::pdo()->prepare('DELETE FROM api_tokens WHERE id = ?')->execute([$tokenId]);
    }

    /** Drop PDO so the next call re-opens GATEKEEPER_AUTH_DB (tests only). */
    public static function resetForTests(): void
    {
        self::$pdo = null;
    }

    /**
     * @param  list<string>  $before
     * @param  list<string>  $after
     */
    private static function assertMayDropAdminAbility(int $userId, array $before, array $after): void
    {
        $hadAdmin = in_array(FleetAbilities::ADMIN, $before, true);
        $hasAdmin = in_array(FleetAbilities::ADMIN, $after, true);
        if ($hadAdmin && ! $hasAdmin) {
            self::assertMayDisableOrDemoteAdmin($userId, $before);
        }
    }

    /** @param  list<string>  $abilities */
    private static function assertMayDisableOrDemoteAdmin(int $userId, array $abilities): void
    {
        if (! in_array(FleetAbilities::ADMIN, $abilities, true)) {
            return;
        }
        if (self::countActiveAdmins($userId) < 1) {
            throw new \RuntimeException('Cannot remove the last active fleet_admin', 422);
        }
    }

    /** Active = not disabled. Optionally exclude one user id from the count. */
    private static function countActiveAdmins(?int $excludeUserId = null): int
    {
        $sql = <<<'SQL'
SELECT COUNT(*) FROM users
WHERE disabled_at IS NULL
  AND abilities LIKE '%"fleet_admin"%'
SQL;
        $params = [];
        if ($excludeUserId !== null) {
            $sql .= ' AND id != ?';
            $params[] = $excludeUserId;
        }
        $st = self::pdo()->prepare($sql);
        $st->execute($params);

        return (int) $st->fetchColumn();
    }

    /**
     * @param  array<string,mixed>  $row
     * @return array{id:int,email:string,name:string,abilities:list<string>,created_at:string,disabled_at:?string,notify_failures:bool,session_count:int}
     */
    private static function mapPublicUserRow(array $row): array
    {
        $abilities = FleetAbilities::normalize($row['abilities'] ?? FleetAbilities::DEFAULT_BOOTSTRAP);
        if ($abilities === []) {
            $abilities = FleetAbilities::DEFAULT_BOOTSTRAP;
        }
        $disabled = $row['disabled_at'] ?? null;

        return [
            'id' => (int) $row['id'],
            'email' => (string) $row['email'],
            'name' => (string) $row['name'],
            'abilities' => $abilities,
            'created_at' => (string) ($row['created_at'] ?? ''),
            'disabled_at' => $disabled !== null && $disabled !== '' ? (string) $disabled : null,
            'notify_failures' => (bool) (int) ($row['notify_failures'] ?? 0),
            'session_count' => (int) ($row['session_count'] ?? 0),
        ];
    }

    /**
     * @param  array<string,mixed>  $row
     * @return array{id:int,email:string,name:string,abilities:list<string>,disabled_at:?string,password_hash?:string}
     */
    private static function mapUserRow(array $row, bool $withPassword): array
    {
        $abilities = FleetAbilities::normalize($row['abilities'] ?? FleetAbilities::DEFAULT_BOOTSTRAP);
        if ($abilities === []) {
            $abilities = FleetAbilities::DEFAULT_BOOTSTRAP;
        }
        $disabled = $row['disabled_at'] ?? null;
        $out = [
            'id' => (int) $row['id'],
            'email' => (string) $row['email'],
            'name' => (string) $row['name'],
            'abilities' => $abilities,
            'disabled_at' => $disabled !== null && $disabled !== '' ? (string) $disabled : null,
        ];
        if ($withPassword) {
            $out['password_hash'] = (string) $row['password_hash'];
        }

        return $out;
    }
}
