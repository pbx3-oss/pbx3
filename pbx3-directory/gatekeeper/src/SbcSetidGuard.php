<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Catalog instance sbc_dispatcher_setid must name a live SBC dispatcher set (S10.4 harden).
 * Catalog is HoR — do not invent setids that the edge cannot route.
 */
final class SbcSetidGuard
{
    /**
     * @return int|null null = omit / do not write
     */
    public static function normalizeOptional(mixed $raw): ?int
    {
        if ($raw === null || $raw === '') {
            return null;
        }
        if (is_bool($raw)) {
            throw new \InvalidArgumentException('sbc_dispatcher_setid must be a positive integer', 422);
        }
        if (is_string($raw) && ! ctype_digit(trim($raw)) && ! preg_match('/^-?\d+$/', trim($raw))) {
            throw new \InvalidArgumentException('sbc_dispatcher_setid must be a positive integer', 422);
        }
        $n = (int) $raw;
        if ($n < 1) {
            throw new \InvalidArgumentException('sbc_dispatcher_setid must be a positive integer', 422);
        }

        return $n;
    }

    /**
     * @param  list<int>  $liveSetids
     */
    public static function assertLive(int $setid, array $liveSetids): void
    {
        if (in_array($setid, $liveSetids, true)) {
            return;
        }
        $list = $liveSetids === [] ? '(none)' : implode(', ', $liveSetids);
        throw new \InvalidArgumentException(
            "sbc_dispatcher_setid {$setid} is not a live SBC dispatcher set; valid: {$list}",
            422
        );
    }

    /**
     * If body includes sbc_dispatcher_setid, normalize + assert against live SBC sets.
     * Empty / null omits the field (no write).
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public static function applyToBody(array $body, SbcFleetClient $sbc): array
    {
        if (! array_key_exists('sbc_dispatcher_setid', $body)) {
            return $body;
        }
        $setid = self::normalizeOptional($body['sbc_dispatcher_setid']);
        if ($setid === null) {
            unset($body['sbc_dispatcher_setid']);

            return $body;
        }
        $live = [];
        foreach ($sbc->listDispatcherSets() as $row) {
            $live[] = (int) $row['setid'];
        }
        self::assertLive($setid, $live);
        $body['sbc_dispatcher_setid'] = $setid;

        return $body;
    }
}
