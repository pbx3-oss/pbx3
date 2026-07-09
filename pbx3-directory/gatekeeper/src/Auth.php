<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

final class Auth
{
    public static function requireBearer(): void
    {
        $expected = getenv('GATEKEEPER_API_TOKEN') ?: '';
        if ($expected === '') {
            throw new \RuntimeException('GATEKEEPER_API_TOKEN not configured', 503);
        }

        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (! preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
            throw new \RuntimeException('Unauthorized', 401);
        }

        if (! hash_equals($expected, trim($m[1]))) {
            throw new \RuntimeException('Unauthorized', 401);
        }
    }
}
