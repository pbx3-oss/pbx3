<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/**
 * Local probe state (SQLite) — consecutive misses, reachability, notify dedup.
 * Catalog S3 keeps last_seen_at only; flap counters stay off the public catalog.
 */
final class InstanceHealthStore
{
    public const DOWN_AFTER_MISSES = 2;

    public static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS instance_health (
    instance_id TEXT PRIMARY KEY,
    reachable INTEGER NOT NULL DEFAULT 1,
    consecutive_misses INTEGER NOT NULL DEFAULT 0,
    last_ok_at TEXT,
    last_probe_at TEXT,
    last_notified_reachable INTEGER
);
SQL);
    }

    /**
     * Apply one probe result. Returns transition for notify: null | 'down' | 'cleared'.
     *
     * @return null|'down'|'cleared'
     */
    public static function recordProbe(string $instanceId, bool $ok, ?string $nowIso = null): ?string
    {
        $instanceId = trim($instanceId);
        if ($instanceId === '') {
            throw new \InvalidArgumentException('instance_id required');
        }
        $now = $nowIso ?? gmdate('c');
        $pdo = UserStore::pdo();
        self::migrate($pdo);

        $row = self::get($instanceId);
        $misses = $row !== null ? (int) $row['consecutive_misses'] : 0;
        $reachable = $row !== null ? (bool) $row['reachable'] : true;
        $lastOk = $row['last_ok_at'] ?? null;
        $lastNotified = $row !== null && $row['last_notified_reachable'] !== null
            ? (bool) $row['last_notified_reachable']
            : null;

        if ($ok) {
            $misses = 0;
            $reachable = true;
            $lastOk = $now;
        } else {
            $misses++;
            if ($misses >= self::DOWN_AFTER_MISSES) {
                $reachable = false;
            }
        }

        $transition = null;
        if (! $reachable && ($lastNotified === null || $lastNotified === true)) {
            $transition = 'down';
            $lastNotified = false;
        } elseif ($reachable && $lastNotified === false) {
            $transition = 'cleared';
            $lastNotified = true;
        }

        $st = $pdo->prepare(<<<'SQL'
INSERT INTO instance_health (
  instance_id, reachable, consecutive_misses, last_ok_at, last_probe_at, last_notified_reachable
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(instance_id) DO UPDATE SET
  reachable = excluded.reachable,
  consecutive_misses = excluded.consecutive_misses,
  last_ok_at = excluded.last_ok_at,
  last_probe_at = excluded.last_probe_at,
  last_notified_reachable = excluded.last_notified_reachable
SQL);
        $st->execute([
            $instanceId,
            $reachable ? 1 : 0,
            $misses,
            $lastOk,
            $now,
            $lastNotified === null ? null : ($lastNotified ? 1 : 0),
        ]);

        return $transition;
    }

    /**
     * @return array{
     *   instance_id:string,
     *   reachable:bool,
     *   consecutive_misses:int,
     *   last_ok_at:?string,
     *   last_probe_at:?string,
     *   last_notified_reachable:?bool
     * }|null
     */
    public static function get(string $instanceId): ?array
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare(
            'SELECT instance_id, reachable, consecutive_misses, last_ok_at, last_probe_at, last_notified_reachable
             FROM instance_health WHERE instance_id = ? LIMIT 1'
        );
        $st->execute([trim($instanceId)]);
        $row = $st->fetch();
        if (! is_array($row)) {
            return null;
        }
        $notified = $row['last_notified_reachable'];

        return [
            'instance_id' => (string) $row['instance_id'],
            'reachable' => (bool) (int) $row['reachable'],
            'consecutive_misses' => (int) $row['consecutive_misses'],
            'last_ok_at' => $row['last_ok_at'] !== null && $row['last_ok_at'] !== '' ? (string) $row['last_ok_at'] : null,
            'last_probe_at' => $row['last_probe_at'] !== null && $row['last_probe_at'] !== '' ? (string) $row['last_probe_at'] : null,
            'last_notified_reachable' => $notified === null ? null : (bool) (int) $notified,
        ];
    }
}
