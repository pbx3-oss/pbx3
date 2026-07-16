<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/** Cooldown so repeated misconfig_register posts do not mail-storm. */
final class OpsEventThrottle
{
    public const DEFAULT_COOLDOWN_SECONDS = 1800;

    public static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS ops_event_throttle (
    event_key TEXT PRIMARY KEY,
    last_notified_at TEXT NOT NULL
);
SQL);
    }

    /**
     * @return bool true if notify should proceed (and records now)
     */
    public static function allow(string $eventKey, int $cooldownSeconds = self::DEFAULT_COOLDOWN_SECONDS): bool
    {
        $eventKey = trim($eventKey);
        if ($eventKey === '') {
            return false;
        }
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare('SELECT last_notified_at FROM ops_event_throttle WHERE event_key = ? LIMIT 1');
        $st->execute([$eventKey]);
        $row = $st->fetch();
        $now = time();
        if (is_array($row) && ! empty($row['last_notified_at'])) {
            $prev = strtotime((string) $row['last_notified_at']);
            if ($prev !== false && ($now - $prev) < $cooldownSeconds) {
                return false;
            }
        }
        $iso = gmdate('c', $now);
        $pdo->prepare(
            'INSERT INTO ops_event_throttle (event_key, last_notified_at) VALUES (?, ?)
             ON CONFLICT(event_key) DO UPDATE SET last_notified_at = excluded.last_notified_at'
        )->execute([$eventKey, $iso]);

        return true;
    }
}
