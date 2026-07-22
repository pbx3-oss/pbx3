<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use PDO;

/**
 * Active–passive SBC edge pair registry (SQLite on control).
 * v0: at most one pair — create via API / Fleet UI; delete then recreate to replace.
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
     * @param  array<string, mixed>  $input
     * @return array<string, mixed>
     */
    public static function create(array $input): array
    {
        $id = trim((string) ($input['id'] ?? ''));
        $label = trim((string) ($input['label'] ?? ''));
        $fqdn = trim((string) ($input['fqdn'] ?? ''));
        $eip = trim((string) ($input['eip'] ?? ''));
        $alloc = trim((string) ($input['allocation_id'] ?? ''));
        $a = trim((string) ($input['member_a_instance_id'] ?? ''));
        $b = trim((string) ($input['member_b_instance_id'] ?? ''));
        $active = strtolower(trim((string) ($input['active_member'] ?? 'a')));
        $mode = strtolower(trim((string) ($input['mode'] ?? self::MODE_MANAGED)));
        $region = trim((string) ($input['region'] ?? 'us-east-1'));
        if ($region === '') {
            $region = 'us-east-1';
        }

        if ($label === '') {
            throw new \InvalidArgumentException('label required');
        }
        if ($id === '') {
            $id = self::slugId($label);
        }
        if (! preg_match('/^[a-z0-9][a-z0-9_-]{1,63}$/', $id)) {
            throw new \InvalidArgumentException('id must be 2–64 chars: lowercase letters, digits, _-');
        }
        if ($fqdn === '' || ! str_contains($fqdn, '.')) {
            throw new \InvalidArgumentException('fqdn required (hostname)');
        }
        if ($eip === '') {
            throw new \InvalidArgumentException('eip required');
        }
        if ($alloc === '' || ! str_starts_with($alloc, 'eipalloc-')) {
            throw new \InvalidArgumentException('allocation_id required (eipalloc-…)');
        }
        if ($a === '' || $b === '' || $a === $b) {
            throw new \InvalidArgumentException('member_a_instance_id and member_b_instance_id required and distinct');
        }
        if ($active !== 'a' && $active !== 'b') {
            throw new \InvalidArgumentException('active_member must be a or b');
        }
        if ($mode !== self::MODE_MANAGED && $mode !== self::MODE_AUTO) {
            throw new \InvalidArgumentException('mode must be managed or auto');
        }
        // v0: one HA pair at a time (delete then recreate to replace)
        if (self::list() !== []) {
            throw new \RuntimeException('an edge pair already exists — delete it before adding another', 409);
        }
        if (self::get($id) !== null) {
            throw new \RuntimeException('edge pair id already exists', 409);
        }

        $now = gmdate('c');
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        $ins = $pdo->prepare(<<<'SQL'
INSERT INTO edge_pairs (
  id, label, fqdn, eip, allocation_id,
  member_a_instance_id, member_b_instance_id,
  active_member, mode, region, enabled, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
SQL);
        $ins->execute([$id, $label, $fqdn, $eip, $alloc, $a, $b, $active, $mode, $region, $now]);

        $row = self::get($id);
        if ($row === null) {
            throw new \RuntimeException('edge pair missing after create', 500);
        }

        return $row;
    }

    private static function slugId(string $label): string
    {
        $s = strtolower($label);
        $s = preg_replace('/[^a-z0-9]+/', '-', $s) ?? '';
        $s = trim($s, '-');
        if ($s === '') {
            $s = 'edge-'.bin2hex(random_bytes(3));
        }

        return substr($s, 0, 64);
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

    /** Remove pair + health row. Does not touch AWS EIP or instances. */
    public static function delete(string $id): void
    {
        $id = trim($id);
        if ($id === '') {
            throw new \InvalidArgumentException('id required');
        }
        if (self::get($id) === null) {
            throw new \RuntimeException('edge pair not found', 404);
        }
        $pdo = UserStore::pdo();
        self::migrate($pdo);
        EdgePairHealthStore::migrate($pdo);
        $pdo->prepare('DELETE FROM edge_pair_health WHERE edge_pair_id = ?')->execute([$id]);
        $pdo->prepare('DELETE FROM edge_pairs WHERE id = ?')->execute([$id]);
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
