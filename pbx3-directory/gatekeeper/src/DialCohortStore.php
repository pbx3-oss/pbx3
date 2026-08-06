<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * C1 — dial cohort (UI: Site Group) catalog HoR + tenant routing_prefix.
 * Materialise jobs / node dialalias projection = C2/C3 (not here).
 *
 * Paths: catalog/dial-cohorts/{id}.json · catalog/dial-cohort-index.json
 *         tenants/{suid}/meta.json (routing_prefix, dial_cohort_id)
 */
final class DialCohortStore
{
    public const STATUS_ACTIVE = 'active';

    public const STATUS_DECOMMISSIONED = 'decommissioned';

    public const DEFAULT_PREFIX_WIDTH = 2;

    public const MIN_PREFIX_WIDTH = 2;

    public const MAX_PREFIX_WIDTH = 4;

    public function __construct(
        private readonly S3Registrar $registrar,
    ) {
    }

    /**
     * @return array{version: int, updated_at: string, cohorts: list<array<string, mixed>>}
     */
    public function listIndex(): array
    {
        return $this->registrar->getDialCohortIndex();
    }

    /** @return array<string, mixed> */
    public function get(string $id): array
    {
        $doc = $this->registrar->getDialCohort($id);
        if ($doc === []) {
            throw new \RuntimeException("Dial cohort not found: {$id}", 404);
        }

        return $doc;
    }

    /**
     * Create empty active cohort (no members yet).
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function create(array $body, ?string $updatedBy = null): array
    {
        $name = trim((string) ($body['name'] ?? ''));
        if ($name === '') {
            throw new \InvalidArgumentException('name required', 422);
        }

        $width = self::normalizePrefixWidth($body['prefix_width'] ?? self::DEFAULT_PREFIX_WIDTH);
        $now = $this->registrar->nowIso();
        $id = self::newCohortId();

        $doc = [
            'id' => $id,
            'name' => $name,
            'members' => [],
            'prefix_width' => $width,
            'status' => self::STATUS_ACTIVE,
            'created_at' => $now,
            'updated_at' => $now,
            'updated_by' => $updatedBy,
        ];

        $this->registrar->putDialCohort($id, $doc);
        $this->upsertIndexRow($doc);

        return $doc;
    }

    /**
     * Patch name and/or prefix_width (no members). Width change rejected if members' prefixes mismatch.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function patch(string $id, array $body, ?string $updatedBy = null): array
    {
        $doc = $this->get($id);
        if (($doc['status'] ?? '') === self::STATUS_DECOMMISSIONED) {
            throw new \RuntimeException('Cannot patch decommissioned dial cohort', 409);
        }

        $changed = false;
        if (array_key_exists('name', $body)) {
            $name = trim((string) $body['name']);
            if ($name === '') {
                throw new \InvalidArgumentException('name must be non-empty', 422);
            }
            $doc['name'] = $name;
            $changed = true;
        }

        if (array_key_exists('prefix_width', $body)) {
            $width = self::normalizePrefixWidth($body['prefix_width']);
            $this->assertMembersMatchWidth($doc, $width);
            $doc['prefix_width'] = $width;
            $changed = true;
        }

        if (! $changed) {
            throw new \InvalidArgumentException('No patchable fields (name, prefix_width)', 422);
        }

        $doc['updated_at'] = $this->registrar->nowIso();
        if ($updatedBy !== null && $updatedBy !== '') {
            $doc['updated_by'] = $updatedBy;
        }
        $this->registrar->putDialCohort($id, $doc);
        $this->upsertIndexRow($doc);

        return $doc;
    }

    /**
     * Soft-decommission: clear member back-pointers, empty members[], status=decommissioned.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function decommission(string $id, array $body, ?string $updatedBy = null): array
    {
        if (empty($body['confirm'])) {
            throw new \InvalidArgumentException('confirm: true required to decommission', 422);
        }

        $doc = $this->get($id);
        if (($doc['status'] ?? '') === self::STATUS_DECOMMISSIONED) {
            return [
                'cohort' => $doc,
                'former_members' => [],
            ];
        }

        $members = self::normalizeMembers($doc['members'] ?? []);
        foreach ($members as $shortuid) {
            $this->detachTenantFromCohort($shortuid, $id, clearPrefix: true, updatedBy: $updatedBy);
        }

        $now = $this->registrar->nowIso();
        $doc['members'] = [];
        $doc['status'] = self::STATUS_DECOMMISSIONED;
        $doc['updated_at'] = $now;
        if ($updatedBy !== null && $updatedBy !== '') {
            $doc['updated_by'] = $updatedBy;
        }
        $this->registrar->putDialCohort($id, $doc);
        $this->upsertIndexRow($doc);

        return [
            'cohort' => $doc,
            'former_members' => $members,
        ];
    }

    /**
     * Add tenant to cohort; require routing_prefix (body or existing meta).
     *
     * @param  array<string, mixed>  $body
     * @return array{cohort: array<string, mixed>, tenant: array<string, mixed>}
     */
    public function addMember(string $id, array $body, ?string $updatedBy = null): array
    {
        $doc = $this->requireActive($id);
        $shortuid = self::normalizeShortuid((string) ($body['tenant_shortuid'] ?? $body['shortuid'] ?? ''));
        $meta = $this->registrar->getTenantMeta($shortuid);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }
        if (strtolower((string) ($meta['status'] ?? 'active')) === 'decommissioned') {
            throw new \InvalidArgumentException("Tenant {$shortuid} is decommissioned", 422);
        }

        $existingCohort = trim((string) ($meta['dial_cohort_id'] ?? ''));
        if ($existingCohort !== '' && $existingCohort !== $id) {
            throw new \RuntimeException(
                "Tenant {$shortuid} already in dial cohort {$existingCohort} (v1: one cohort)",
                409
            );
        }

        $members = self::normalizeMembers($doc['members'] ?? []);
        if (in_array($shortuid, $members, true)) {
            throw new \RuntimeException("Tenant {$shortuid} already a member", 409);
        }

        $width = (int) ($doc['prefix_width'] ?? self::DEFAULT_PREFIX_WIDTH);
        $prefix = array_key_exists('routing_prefix', $body)
            ? self::normalizeRoutingPrefix((string) $body['routing_prefix'], $width)
            : self::normalizeRoutingPrefix((string) ($meta['routing_prefix'] ?? ''), $width);

        if ($prefix === '') {
            throw new \InvalidArgumentException(
                'routing_prefix required when joining a dial cohort ('.$width.' digits)',
                422
            );
        }

        $this->assertPrefixUnique($prefix, $shortuid);

        $members[] = $shortuid;
        sort($members);
        $doc['members'] = $members;
        $doc['updated_at'] = $this->registrar->nowIso();
        if ($updatedBy !== null && $updatedBy !== '') {
            $doc['updated_by'] = $updatedBy;
        }
        $this->registrar->putDialCohort($id, $doc);

        $meta['routing_prefix'] = $prefix;
        $meta['routing_prefix_width'] = $width;
        $meta['dial_cohort_id'] = $id;
        $meta['updated_at'] = $doc['updated_at'];
        if ($updatedBy !== null && $updatedBy !== '') {
            $meta['updated_by'] = $updatedBy;
        }
        $meta = $this->registrar->putTenantMeta($shortuid, $meta);

        $this->upsertIndexRow($doc);

        return ['cohort' => $doc, 'tenant' => $meta];
    }

    /**
     * Remove tenant from cohort; clears dial_cohort_id + routing_prefix (isolate).
     *
     * @return array{cohort: array<string, mixed>, tenant: array<string, mixed>}
     */
    public function removeMember(string $id, string $shortuid, ?string $updatedBy = null): array
    {
        $doc = $this->requireActive($id);
        $shortuid = self::normalizeShortuid($shortuid);
        $members = self::normalizeMembers($doc['members'] ?? []);
        if (! in_array($shortuid, $members, true)) {
            throw new \RuntimeException("Tenant {$shortuid} is not a member of {$id}", 404);
        }

        $doc['members'] = array_values(array_filter($members, static fn (string $s): bool => $s !== $shortuid));
        $doc['updated_at'] = $this->registrar->nowIso();
        if ($updatedBy !== null && $updatedBy !== '') {
            $doc['updated_by'] = $updatedBy;
        }
        $this->registrar->putDialCohort($id, $doc);

        $meta = $this->detachTenantFromCohort($shortuid, $id, clearPrefix: true, updatedBy: $updatedBy);
        $this->upsertIndexRow($doc);

        return ['cohort' => $doc, 'tenant' => $meta];
    }

    /**
     * Set or clear routing_prefix on a tenant. If in a cohort, prefix must match cohort width + stay unique.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function setRoutingPrefix(string $shortuid, array $body, ?string $updatedBy = null): array
    {
        $shortuid = self::normalizeShortuid($shortuid);
        $meta = $this->registrar->getTenantMeta($shortuid);
        if ($meta === []) {
            throw new \RuntimeException("Tenant not found: {$shortuid}", 404);
        }

        $cohortId = trim((string) ($meta['dial_cohort_id'] ?? ''));
        $width = self::DEFAULT_PREFIX_WIDTH;
        if ($cohortId !== '') {
            $doc = $this->get($cohortId);
            $width = (int) ($doc['prefix_width'] ?? self::DEFAULT_PREFIX_WIDTH);
        } elseif (isset($body['routing_prefix_width'])) {
            $width = self::normalizePrefixWidth($body['routing_prefix_width']);
        } elseif (isset($meta['routing_prefix_width'])) {
            $width = self::normalizePrefixWidth($meta['routing_prefix_width']);
        }

        if (! array_key_exists('routing_prefix', $body)) {
            throw new \InvalidArgumentException('routing_prefix required (use empty string to clear)', 422);
        }

        $raw = $body['routing_prefix'];
        if ($raw === null || (is_string($raw) && trim($raw) === '')) {
            if ($cohortId !== '') {
                throw new \InvalidArgumentException(
                    'Cannot clear routing_prefix while tenant is in a dial cohort — remove member first',
                    422
                );
            }
            unset($meta['routing_prefix'], $meta['routing_prefix_width']);
            $meta['routing_prefix'] = '';
        } else {
            $prefix = self::normalizeRoutingPrefix((string) $raw, $width);
            if ($prefix === '') {
                throw new \InvalidArgumentException(
                    'routing_prefix must be exactly '.$width.' digits',
                    422
                );
            }
            $this->assertPrefixUnique($prefix, $shortuid);
            $meta['routing_prefix'] = $prefix;
            $meta['routing_prefix_width'] = $width;
        }

        $meta['updated_at'] = $this->registrar->nowIso();
        if ($updatedBy !== null && $updatedBy !== '') {
            $meta['updated_by'] = $updatedBy;
        }
        $meta = $this->registrar->putTenantMeta($shortuid, $meta);

        if ($cohortId !== '') {
            $this->upsertIndexRow($this->get($cohortId));
        }

        return $meta;
    }

    /**
     * Full rebuild of catalog/dial-cohort-index.json from S3 cohort docs.
     *
     * @return array{version: int, updated_at: string, cohorts: list<array<string, mixed>>}
     */
    public function rebuildIndex(): array
    {
        return $this->writeIndexFromIds($this->registrar->listDialCohortIds());
    }

    /**
     * Upsert one cohort into the index.
     *
     * @param  array<string, mixed>  $doc
     * @return array{version: int, updated_at: string, cohorts: list<array<string, mixed>>}
     */
    public function upsertIndexRow(array $doc): array
    {
        $index = $this->registrar->getDialCohortIndex();
        $row = $this->indexRowFromDoc($doc);
        $cohorts = [];
        $found = false;
        foreach ($index['cohorts'] ?? [] as $existing) {
            if (! is_array($existing)) {
                continue;
            }
            if (($existing['id'] ?? '') === $row['id']) {
                $cohorts[] = $row;
                $found = true;
            } else {
                $cohorts[] = $existing;
            }
        }
        if (! $found) {
            $cohorts[] = $row;
        }
        usort($cohorts, static fn (array $a, array $b): int => strcmp((string) ($a['name'] ?? ''), (string) ($b['name'] ?? '')));

        $out = [
            'version' => 1,
            'updated_at' => $this->registrar->nowIso(),
            'cohorts' => $cohorts,
        ];
        $this->registrar->putDialCohortIndex($out);

        return $out;
    }

    // ── pure helpers (tests) ──────────────────────────────────────────

    public static function newCohortId(): string
    {
        // Compact KSUID-style id (27 chars base62-ish via hex slice + prefix).
        return 'dc_'.bin2hex(random_bytes(12));
    }

    public static function normalizePrefixWidth(mixed $raw): int
    {
        $width = is_int($raw) ? $raw : (int) $raw;
        if ($width < self::MIN_PREFIX_WIDTH || $width > self::MAX_PREFIX_WIDTH) {
            throw new \InvalidArgumentException(
                'prefix_width must be '.self::MIN_PREFIX_WIDTH.'–'.self::MAX_PREFIX_WIDTH,
                422
            );
        }

        return $width;
    }

    /**
     * Digits only; empty allowed; if non-empty must equal $width.
     */
    public static function normalizeRoutingPrefix(string $raw, int $width): string
    {
        $digits = preg_replace('/\D+/', '', trim($raw)) ?? '';
        if ($digits === '') {
            return '';
        }
        if (strlen($digits) !== $width) {
            throw new \InvalidArgumentException(
                "routing_prefix must be exactly {$width} digits",
                422
            );
        }

        return $digits;
    }

    public static function normalizeShortuid(string $raw): string
    {
        $shortuid = strtolower(trim($raw));
        if ($shortuid === '' || ! preg_match('/^[a-z0-9]+$/', $shortuid)) {
            throw new \InvalidArgumentException('tenant_shortuid required (lowercase alnum)', 422);
        }

        return $shortuid;
    }

    /**
     * @param  mixed  $members
     * @return list<string>
     */
    public static function normalizeMembers(mixed $members): array
    {
        if (! is_array($members)) {
            return [];
        }
        $out = [];
        foreach ($members as $m) {
            if (! is_string($m)) {
                continue;
            }
            $s = strtolower(trim($m));
            if ($s !== '' && preg_match('/^[a-z0-9]+$/', $s)) {
                $out[] = $s;
            }
        }

        return array_values(array_unique($out));
    }

    /**
     * Pure index row builder for tests.
     *
     * @param  array<string, mixed>  $doc
     * @param  array<string, array<string, mixed>>  $metasByShortuid
     * @return array<string, mixed>
     */
    public static function buildIndexRow(array $doc, array $metasByShortuid = []): array
    {
        $members = self::normalizeMembers($doc['members'] ?? []);
        $width = (int) ($doc['prefix_width'] ?? self::DEFAULT_PREFIX_WIDTH);
        $ready = 0;
        foreach ($members as $suid) {
            $prefix = (string) ($metasByShortuid[$suid]['routing_prefix'] ?? '');
            if ($prefix !== '' && strlen($prefix) === $width && ctype_digit($prefix)) {
                $ready++;
            }
        }

        return [
            'id' => (string) ($doc['id'] ?? ''),
            'name' => (string) ($doc['name'] ?? ''),
            'member_count' => count($members),
            'prefixes_ready' => $ready,
            'prefix_width' => $width,
            'status' => (string) ($doc['status'] ?? self::STATUS_ACTIVE),
            'updated_at' => (string) ($doc['updated_at'] ?? ''),
        ];
    }

    // ── private ───────────────────────────────────────────────────────

    /** @return array<string, mixed> */
    private function requireActive(string $id): array
    {
        $doc = $this->get($id);
        if (($doc['status'] ?? '') !== self::STATUS_ACTIVE) {
            throw new \RuntimeException('Dial cohort is not active', 409);
        }

        return $doc;
    }

    /** @param array<string, mixed> $doc */
    private function assertMembersMatchWidth(array $doc, int $width): void
    {
        foreach (self::normalizeMembers($doc['members'] ?? []) as $shortuid) {
            $meta = $this->registrar->getTenantMeta($shortuid);
            $prefix = (string) ($meta['routing_prefix'] ?? '');
            if ($prefix === '') {
                continue;
            }
            if (strlen($prefix) !== $width) {
                throw new \InvalidArgumentException(
                    "Cannot set prefix_width={$width}: member {$shortuid} has routing_prefix length ".strlen($prefix),
                    422
                );
            }
        }
    }

    private function assertPrefixUnique(string $prefix, string $exceptShortuid): void
    {
        foreach ($this->registrar->listTenants() as $meta) {
            $suid = strtolower(trim((string) ($meta['shortuid'] ?? $meta['tenant_shortuid'] ?? '')));
            if ($suid === '' || $suid === $exceptShortuid) {
                continue;
            }
            $other = (string) ($meta['routing_prefix'] ?? '');
            if ($other !== '' && $other === $prefix) {
                throw new \RuntimeException(
                    "routing_prefix {$prefix} already used by tenant {$suid}",
                    409
                );
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function detachTenantFromCohort(
        string $shortuid,
        string $cohortId,
        bool $clearPrefix,
        ?string $updatedBy
    ): array {
        $meta = $this->registrar->getTenantMeta($shortuid);
        if ($meta === []) {
            return [];
        }
        $current = trim((string) ($meta['dial_cohort_id'] ?? ''));
        if ($current !== '' && $current !== $cohortId) {
            return $meta;
        }
        $meta['dial_cohort_id'] = null;
        if ($clearPrefix) {
            $meta['routing_prefix'] = '';
            unset($meta['routing_prefix_width']);
        }
        $meta['updated_at'] = $this->registrar->nowIso();
        if ($updatedBy !== null && $updatedBy !== '') {
            $meta['updated_by'] = $updatedBy;
        }

        return $this->registrar->putTenantMeta($shortuid, $meta);
    }

    /** @param array<string, mixed> $doc */
    private function indexRowFromDoc(array $doc): array
    {
        $metas = [];
        foreach (self::normalizeMembers($doc['members'] ?? []) as $suid) {
            $meta = $this->registrar->getTenantMeta($suid);
            if ($meta !== []) {
                $metas[$suid] = $meta;
            }
        }

        return self::buildIndexRow($doc, $metas);
    }

    /**
     * @param  list<string>  $ids
     * @return array{version: int, updated_at: string, cohorts: list<array<string, mixed>>}
     */
    private function writeIndexFromIds(array $ids): array
    {
        $rows = [];
        foreach ($ids as $id) {
            $doc = $this->registrar->getDialCohort($id);
            if ($doc === []) {
                continue;
            }
            $rows[] = $this->indexRowFromDoc($doc);
        }
        usort($rows, static fn (array $a, array $b): int => strcmp((string) ($a['name'] ?? ''), (string) ($b['name'] ?? '')));

        $out = [
            'version' => 1,
            'updated_at' => $this->registrar->nowIso(),
            'cohorts' => $rows,
        ];
        $this->registrar->putDialCohortIndex($out);

        return $out;
    }
}
