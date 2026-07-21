<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/** Probe hysteresis for edge pairs (SIP OPTIONS on VIP). */
final class EdgePairHealthStore
{
    public const DOWN_AFTER_MISSES = 2;

    public static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS edge_pair_health (
    edge_pair_id TEXT PRIMARY KEY,
    reachable INTEGER NOT NULL DEFAULT 1,
    consecutive_misses INTEGER NOT NULL DEFAULT 0,
    last_ok_at TEXT,
    last_probe_at TEXT,
    last_notified_reachable INTEGER,
    last_rtt_ms INTEGER
);
SQL);
    }

    /**
     * @return null|'down'|'cleared'
     */
    public static function recordProbe(
        string $edgePairId,
        bool $ok,
        ?int $rttMs = null,
        ?string $nowIso = null,
    ): ?string {
        $edgePairId = trim($edgePairId);
        if ($edgePairId === '') {
            throw new \InvalidArgumentException('edge_pair_id required');
        }
        $now = $nowIso ?? gmdate('c');
        $pdo = UserStore::pdo();
        self::migrate($pdo);

        $row = self::get($edgePairId);
        $misses = $row !== null ? (int) $row['consecutive_misses'] : 0;
        $reachable = $row !== null ? (bool) $row['reachable'] : true;
        $lastOk = $row['last_ok_at'] ?? null;
        $lastRtt = $row['last_rtt_ms'] ?? null;
        $lastNotified = $row !== null && $row['last_notified_reachable'] !== null
            ? (bool) $row['last_notified_reachable']
            : null;

        if ($ok) {
            $misses = 0;
            $reachable = true;
            $lastOk = $now;
            if ($rttMs !== null && $rttMs >= 0) {
                $lastRtt = $rttMs;
            }
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
INSERT INTO edge_pair_health (
  edge_pair_id, reachable, consecutive_misses, last_ok_at, last_probe_at, last_notified_reachable, last_rtt_ms
) VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(edge_pair_id) DO UPDATE SET
  reachable = excluded.reachable,
  consecutive_misses = excluded.consecutive_misses,
  last_ok_at = excluded.last_ok_at,
  last_probe_at = excluded.last_probe_at,
  last_notified_reachable = excluded.last_notified_reachable,
  last_rtt_ms = excluded.last_rtt_ms
SQL);
        $st->execute([
            $edgePairId,
            $reachable ? 1 : 0,
            $misses,
            $lastOk,
            $now,
            $lastNotified === null ? null : ($lastNotified ? 1 : 0),
            $lastRtt,
        ]);

        return $transition;
    }

    /**
     * @return array{
     *   edge_pair_id:string,
     *   reachable:bool,
     *   consecutive_misses:int,
     *   last_ok_at:?string,
     *   last_probe_at:?string,
     *   last_notified_reachable:?bool,
     *   last_rtt_ms:?int
     * }|null
     */
    public static function get(string $edgePairId): ?array
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare(
            'SELECT edge_pair_id, reachable, consecutive_misses, last_ok_at, last_probe_at,
                    last_notified_reachable, last_rtt_ms
             FROM edge_pair_health WHERE edge_pair_id = ? LIMIT 1'
        );
        $st->execute([trim($edgePairId)]);
        $row = $st->fetch(PDO::FETCH_ASSOC);
        if (! is_array($row)) {
            return null;
        }
        $notified = $row['last_notified_reachable'];
        $rtt = $row['last_rtt_ms'] ?? null;

        return [
            'edge_pair_id' => (string) $row['edge_pair_id'],
            'reachable' => (bool) (int) $row['reachable'],
            'consecutive_misses' => (int) $row['consecutive_misses'],
            'last_ok_at' => $row['last_ok_at'] !== null && $row['last_ok_at'] !== '' ? (string) $row['last_ok_at'] : null,
            'last_probe_at' => $row['last_probe_at'] !== null && $row['last_probe_at'] !== '' ? (string) $row['last_probe_at'] : null,
            'last_notified_reachable' => $notified === null ? null : (bool) (int) $notified,
            'last_rtt_ms' => $rtt !== null && $rtt !== '' ? (int) $rtt : null,
        ];
    }
}
