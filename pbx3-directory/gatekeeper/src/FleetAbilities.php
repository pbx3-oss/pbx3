<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Gatekeeper fleet ability vocabulary (S10.1 / Rule 10).
 * Owned in-house; optional IdP later only maps groups → these names.
 */
final class FleetAbilities
{
    public const READ = 'fleet_read';

    public const INSTANCES = 'fleet_instances';

    public const MOVES = 'fleet_moves';

    public const EDGE = 'fleet_edge';

    /** Dial cohort / Site Group CRUD + routing prefix (C1+). Not folded into fleet_instances. */
    public const DIAL_COHORTS = 'fleet_dial_cohorts';

    public const ADMIN = 'fleet_admin';

    /** @var list<string> */
    public const ALL = [
        self::READ,
        self::INSTANCES,
        self::MOVES,
        self::EDGE,
        self::DIAL_COHORTS,
        self::ADMIN,
    ];

    /** Bootstrap / break-glass: full power. */
    /** @var list<string> */
    public const DEFAULT_BOOTSTRAP = [self::ADMIN];

    /** @return list<string> */
    public static function normalize(mixed $raw): array
    {
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true);
            $raw = is_array($decoded) ? $decoded : [];
        }
        if (! is_array($raw)) {
            return [];
        }
        $out = [];
        foreach ($raw as $item) {
            if (! is_string($item)) {
                continue;
            }
            $ability = trim($item);
            if ($ability !== '' && in_array($ability, self::ALL, true)) {
                $out[] = $ability;
            }
        }

        return array_values(array_unique($out));
    }

    public static function toJson(array $abilities): string
    {
        return json_encode(self::normalize($abilities), JSON_THROW_ON_ERROR);
    }

    /**
     * fleet_admin expands to the full set (for /me SPA UX).
     *
     * @param  list<string>  $held
     * @return list<string>
     */
    public static function expand(array $held): array
    {
        $held = self::normalize($held);
        if (in_array(self::ADMIN, $held, true)) {
            return self::ALL;
        }

        return $held;
    }

    /**
     * @param  list<string>  $held
     */
    public static function grants(array $held, string $needed): bool
    {
        $held = self::normalize($held);
        if (in_array(self::ADMIN, $held, true)) {
            return true;
        }

        return in_array($needed, $held, true);
    }
}
