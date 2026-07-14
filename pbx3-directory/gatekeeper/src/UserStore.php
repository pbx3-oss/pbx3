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
    created_at TEXT NOT NULL
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
    }

    /** @return array{id:int,email:string,name:string}|null */
    public static function findByEmail(string $email): ?array
    {
        $st = self::pdo()->prepare('SELECT id, email, name, password_hash FROM users WHERE email = ? COLLATE NOCASE LIMIT 1');
        $st->execute([trim($email)]);
        $row = $st->fetch();
        if (! is_array($row)) {
            return null;
        }

        return [
            'id' => (int) $row['id'],
            'email' => (string) $row['email'],
            'name' => (string) $row['name'],
            'password_hash' => (string) $row['password_hash'],
        ];
    }

    public static function userCount(): int
    {
        return (int) self::pdo()->query('SELECT COUNT(*) FROM users')->fetchColumn();
    }

    /** @return array{id:int,email:string,name:string} */
    public static function createUser(string $email, string $password, string $name = ''): array
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
        $now = gmdate('c');
        $st = self::pdo()->prepare('INSERT INTO users (email, name, password_hash, created_at) VALUES (?, ?, ?, ?)');
        $st->execute([$email, trim($name) !== '' ? trim($name) : $email, $hash, $now]);

        return [
            'id' => (int) self::pdo()->lastInsertId(),
            'email' => $email,
            'name' => trim($name) !== '' ? trim($name) : $email,
        ];
    }

    /**
     * @return array{token:string,user:array{id:int,email:string,name:string},expires_at:?string}
     */
    public static function login(string $email, string $password, int $ttlSeconds = 86400 * 7): array
    {
        $row = self::findByEmail($email);
        if ($row === null || ! password_verify($password, $row['password_hash'])) {
            throw new \RuntimeException('Invalid email or password', 401);
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
            ],
        ];
    }

    /** @return array{id:int,email:string,name:string}|null */
    public static function userForToken(string $plainToken): ?array
    {
        $hash = hash('sha256', $plainToken);
        $st = self::pdo()->prepare(<<<'SQL'
SELECT u.id, u.email, u.name, t.id AS token_id, t.expires_at
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
        if (! empty($row['expires_at']) && strtotime((string) $row['expires_at']) < time()) {
            self::pdo()->prepare('DELETE FROM api_tokens WHERE id = ?')->execute([(int) $row['token_id']]);

            return null;
        }

        return [
            'id' => (int) $row['id'],
            'email' => (string) $row['email'],
            'name' => (string) $row['name'],
            'token_id' => (int) $row['token_id'],
        ];
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
}
