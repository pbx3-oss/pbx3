<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Fleet velocity policy — S3 HoR catalog/velocity-policy.json (Gatekeeper sole writer).
 * Spec: FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md L1 / WP3.
 */
final class VelocityPolicyStore
{
    public const S3_KEY = 'catalog/velocity-policy.json';

    public function __construct(
        private readonly S3Registrar $registrar,
    ) {
    }

    /** @return array<string, mixed> */
    public function get(): array
    {
        $doc = $this->registrar->getVelocityPolicy();
        if ($doc === []) {
            return self::defaults($this->registrar->nowIso());
        }

        return self::normalize($doc, $this->registrar->nowIso());
    }

    /**
     * Replace policy document (full PUT).
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function put(array $body, ?string $updatedBy = null): array
    {
        $now = $this->registrar->nowIso();
        $doc = self::normalize(array_merge(self::defaults($now), $body), $now);
        $doc['updated_at'] = $now;
        $doc['updated_by'] = $updatedBy;
        $this->registrar->putVelocityPolicy($doc);

        return $doc;
    }

    /** @return array<string, mixed> */
    public static function defaults(string $updatedAt): array
    {
        return [
            'version' => 1,
            'updated_at' => $updatedAt,
            'updated_by' => null,
            'irsf' => [
                'n' => 10,
                't_minutes' => 5,
                'q_minutes' => 30,
                'prefixes' => ['0900', '+44900', '0044900'],
                'act_enabled' => false,
            ],
            'detectors' => [
                'irsf' => true,
                'off_hours' => false,
            ],
            'off_hours' => [
                'tz' => 'UTC',
                'windows' => [
                    ['dow' => [6, 0], 'start' => '18:00', 'end' => '06:00'],
                ],
                'n' => 20,
                't_minutes' => 60,
            ],
            'allowlist_extensions' => [],
        ];
    }

    /**
     * @param  array<string, mixed>  $raw
     * @return array<string, mixed>
     */
    public static function normalize(array $raw, string $fallbackUpdatedAt): array
    {
        $base = self::defaults($fallbackUpdatedAt);
        $irsfIn = is_array($raw['irsf'] ?? null) ? $raw['irsf'] : [];
        $detIn = is_array($raw['detectors'] ?? null) ? $raw['detectors'] : [];
        $ohIn = is_array($raw['off_hours'] ?? null) ? $raw['off_hours'] : [];

        $prefixes = self::normalizePrefixes($irsfIn['prefixes'] ?? $base['irsf']['prefixes']);
        if ($prefixes === []) {
            throw new \InvalidArgumentException('irsf.prefixes must be a non-empty list', 422);
        }

        $windows = self::normalizeWindows($ohIn['windows'] ?? $base['off_hours']['windows']);

        $allow = [];
        if (isset($raw['allowlist_extensions']) && is_array($raw['allowlist_extensions'])) {
            foreach ($raw['allowlist_extensions'] as $item) {
                if (! is_string($item)) {
                    continue;
                }
                $t = trim($item);
                if ($t !== '') {
                    $allow[] = $t;
                }
            }
        }

        $updatedAt = trim((string) ($raw['updated_at'] ?? ''));
        if ($updatedAt === '') {
            $updatedAt = $fallbackUpdatedAt;
        }

        $updatedBy = $raw['updated_by'] ?? null;
        if ($updatedBy !== null && ! is_string($updatedBy)) {
            $updatedBy = null;
        }

        return [
            'version' => 1,
            'updated_at' => $updatedAt,
            'updated_by' => $updatedBy,
            'irsf' => [
                'n' => max(1, (int) ($irsfIn['n'] ?? $base['irsf']['n'])),
                't_minutes' => max(1, (int) ($irsfIn['t_minutes'] ?? $base['irsf']['t_minutes'])),
                'q_minutes' => max(1, (int) ($irsfIn['q_minutes'] ?? $base['irsf']['q_minutes'])),
                'prefixes' => $prefixes,
                'act_enabled' => filter_var($irsfIn['act_enabled'] ?? $base['irsf']['act_enabled'], FILTER_VALIDATE_BOOL),
            ],
            'detectors' => [
                'irsf' => filter_var($detIn['irsf'] ?? $base['detectors']['irsf'], FILTER_VALIDATE_BOOL),
                'off_hours' => filter_var($detIn['off_hours'] ?? $base['detectors']['off_hours'], FILTER_VALIDATE_BOOL),
            ],
            'off_hours' => [
                'tz' => trim((string) ($ohIn['tz'] ?? $base['off_hours']['tz'])) ?: 'UTC',
                'windows' => $windows,
                'n' => max(1, (int) ($ohIn['n'] ?? $base['off_hours']['n'])),
                't_minutes' => max(1, (int) ($ohIn['t_minutes'] ?? $base['off_hours']['t_minutes'])),
            ],
            'allowlist_extensions' => array_values(array_unique($allow)),
        ];
    }

    /**
     * @param  mixed  $raw
     * @return list<string>
     */
    private static function normalizePrefixes(mixed $raw): array
    {
        if (is_string($raw)) {
            $raw = preg_split('/\s*,\s*/', $raw) ?: [];
        }
        if (! is_array($raw)) {
            return [];
        }
        $out = [];
        foreach ($raw as $p) {
            if (! is_string($p) && ! is_int($p)) {
                continue;
            }
            $t = trim((string) $p);
            if ($t !== '') {
                $out[] = $t;
            }
        }

        return array_values(array_unique($out));
    }

    /**
     * @param  mixed  $raw
     * @return list<array{dow: list<int>, start: string, end: string}>
     */
    private static function normalizeWindows(mixed $raw): array
    {
        if (! is_array($raw) || $raw === []) {
            return [
                ['dow' => [6, 0], 'start' => '18:00', 'end' => '06:00'],
            ];
        }
        $out = [];
        foreach ($raw as $w) {
            if (! is_array($w)) {
                continue;
            }
            $dow = [];
            foreach ((array) ($w['dow'] ?? []) as $d) {
                $i = (int) $d;
                if ($i >= 0 && $i <= 6) {
                    $dow[] = $i;
                }
            }
            $start = trim((string) ($w['start'] ?? ''));
            $end = trim((string) ($w['end'] ?? ''));
            if ($dow === [] || ! preg_match('/^\d{2}:\d{2}$/', $start) || ! preg_match('/^\d{2}:\d{2}$/', $end)) {
                continue;
            }
            $out[] = [
                'dow' => array_values(array_unique($dow)),
                'start' => $start,
                'end' => $end,
            ];
        }

        return $out !== [] ? $out : [
            ['dow' => [6, 0], 'start' => '18:00', 'end' => '06:00'],
        ];
    }
}
