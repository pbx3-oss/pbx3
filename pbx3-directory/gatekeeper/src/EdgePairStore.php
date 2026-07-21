<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/**
 * Active–passive SBC edge pair registry (SQLite on control).
 * Lab FO pair is seeded once; not Magrathea / live sbc.pbx3.com.
 */
final class EdgePairStore
{
    public const MODE_MANAGED = 'managed';

    public const MODE_AUTO = 'auto';

    public const FO_LAB_ID = 'fo-lab';

    public static function migrate(PDO $pdo): void
    {
        $pdo->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS edge_pairs (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    fqdn TEXT NOT NULL,
    eip TEXT NOT NULL,
    allocation_id TEXT NOT NULL,
    member_a_instance_id TEXT NOT NULL,
    member_b_instance_id TEXT NOT NULL,
    active_member TEXT NOT NULL DEFAULT 'b',
    mode TEXT NOT NULL DEFAULT 'managed',
    region TEXT NOT NULL DEFAULT 'us-east-1',
    enabled INTEGER NOT NULL DEFAULT 1,
    promote_cooldown_until TEXT,
    last_promote_at TEXT,
    updated_at TEXT
);
SQL);
        self::seedFoLabIfMissing($pdo);
    }

    private static function seedFoLabIfMissing(PDO $pdo): void
    {
        $st = $pdo->prepare('SELECT id FROM edge_pairs WHERE id = ? LIMIT 1');
        $st->execute([self::FO_LAB_ID]);
        if ($st->fetch()) {
            return;
        }
        $now = gmdate('c');
        $ins = $pdo->prepare(<<<'SQL'
INSERT INTO edge_pairs (
  id, label, fqdn, eip, allocation_id,
  member_a_instance_id, member_b_instance_id,
  active_member, mode, region, enabled, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
SQL);
        // FO1 owns EIP after 2026-07-21 auto-promote drill (was FO2 after manual drill)
        $ins->execute([
            self::FO_LAB_ID,
            'FO lab pair',
            'sbcfo.pbx3.com',
            '98.82.58.59',
            'eipalloc-020e72437124c600e',
            'i-05b30224300cc8812',
            'i-00f85b1c3f18c434e',
            'a',
            self::MODE_MANAGED,
            'us-east-1',
            $now,
        ]);
    }

    /** @return list<array<string, mixed>> */
    public static function list(): array
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $rows = $pdo->query(
            'SELECT * FROM edge_pairs ORDER BY label COLLATE NOCASE ASC'
        )->fetchAll(PDO::FETCH_ASSOC);

        return array_map([self::class, 'normalize'], $rows ?: []);
    }

    /** @return array<string, mixed>|null */
    public static function get(string $id): ?array
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare('SELECT * FROM edge_pairs WHERE id = ? LIMIT 1');
        $st->execute([trim($id)]);
        $row = $st->fetch(PDO::FETCH_ASSOC);
        if (! is_array($row)) {
            return null;
        }

        return self::normalize($row);
    }

    /**
     * @param  array<string, mixed>  $patch
     * @return array<string, mixed>
     */
    public static function patch(string $id, array $patch): array
    {
        $id = trim($id);
        $existing = self::get($id);
        if ($existing === null) {
            throw new \RuntimeException('edge pair not found', 404);
        }

        $label = array_key_exists('label', $patch) ? trim((string) $patch['label']) : (string) $existing['label'];
        $active = array_key_exists('active_member', $patch)
            ? strtolower(trim((string) $patch['active_member']))
            : (string) $existing['active_member'];
        $mode = array_key_exists('mode', $patch)
            ? strtolower(trim((string) $patch['mode']))
            : (string) $existing['mode'];
        $enabled = array_key_exists('enabled', $patch)
            ? (bool) $patch['enabled']
            : (bool) $existing['enabled'];

        if ($label === '') {
            throw new \InvalidArgumentException('label required');
        }
        if ($active !== 'a' && $active !== 'b') {
            throw new \InvalidArgumentException('active_member must be a or b');
        }
        if ($mode !== self::MODE_MANAGED && $mode !== self::MODE_AUTO) {
            throw new \InvalidArgumentException('mode must be managed or auto');
        }

        $now = gmdate('c');
        $pdo = UserStore::pdo();
        $st = $pdo->prepare(<<<'SQL'
UPDATE edge_pairs SET
  label = ?, active_member = ?, mode = ?, enabled = ?, updated_at = ?
WHERE id = ?
SQL);
        $st->execute([$label, $active, $mode, $enabled ? 1 : 0, $now, $id]);

        $row = self::get($id);
        if ($row === null) {
            throw new \RuntimeException('edge pair missing after patch', 500);
        }

        return $row;
    }

    public static function setActiveMember(string $id, string $member, ?string $nowIso = null): void
    {
        $member = strtolower(trim($member));
        if ($member !== 'a' && $member !== 'b') {
            throw new \InvalidArgumentException('active_member must be a or b');
        }
        $now = $nowIso ?? gmdate('c');
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare(
            'UPDATE edge_pairs SET active_member = ?, last_promote_at = ?, updated_at = ? WHERE id = ?'
        );
        $st->execute([$member, $now, $now, trim($id)]);
    }

    public static function setPromoteCooldown(string $id, string $untilIso): void
    {
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $st = $pdo->prepare(
            'UPDATE edge_pairs SET promote_cooldown_until = ?, updated_at = ? WHERE id = ?'
        );
        $st->execute([$untilIso, gmdate('c'), trim($id)]);
    }

    /** @param  array<string, mixed>  $row */
    private static function normalize(array $row): array
    {
        return [
            'id' => (string) $row['id'],
            'label' => (string) $row['label'],
            'fqdn' => (string) $row['fqdn'],
            'eip' => (string) $row['eip'],
            'allocation_id' => (string) $row['allocation_id'],
            'member_a_instance_id' => (string) $row['member_a_instance_id'],
            'member_b_instance_id' => (string) $row['member_b_instance_id'],
            'active_member' => (string) $row['active_member'],
            'mode' => (string) $row['mode'],
            'region' => (string) $row['region'],
            'enabled' => (bool) (int) $row['enabled'],
            'promote_cooldown_until' => self::nullStr($row['promote_cooldown_until'] ?? null),
            'last_promote_at' => self::nullStr($row['last_promote_at'] ?? null),
            'updated_at' => self::nullStr($row['updated_at'] ?? null),
        ];
    }

    private static function nullStr(mixed $v): ?string
    {
        if ($v === null || $v === '') {
            return null;
        }

        return (string) $v;
    }
}
