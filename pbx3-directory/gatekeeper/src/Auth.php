<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

final class Auth
{
    /** @var array{id:int,email:string,name:string,abilities:list<string>,token_id?:int}|null */
    private static ?array $user = null;

    private static bool $breakGlass = false;

    public static function requireBearer(): void
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (! preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
            throw new \RuntimeException('Unauthorized', 401);
        }
        $token = trim($m[1]);
        if ($token === '') {
            throw new \RuntimeException('Unauthorized', 401);
        }

        $expected = getenv('GATEKEEPER_API_TOKEN') ?: '';
        if ($expected !== '' && hash_equals($expected, $token)) {
            self::$breakGlass = true;
            self::$user = [
                'id' => 0,
                'email' => 'break-glass@local',
                'name' => 'Break-glass API token',
                'abilities' => FleetAbilities::DEFAULT_BOOTSTRAP,
            ];

            return;
        }

        $user = UserStore::userForToken($token);
        if ($user === null) {
            throw new \RuntimeException('Unauthorized', 401);
        }
        self::$breakGlass = false;
        self::$user = $user;
    }

    /** Raw Bearer token from the request (for logout). */
    public static function bearerToken(): string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (! preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
            return '';
        }

        return trim($m[1]);
    }

    /**
     * @return array{id:int,email:string,name:string,abilities:list<string>,token_id?:int}|null
     */
    public static function user(): ?array
    {
        return self::$user;
    }

    /** @return list<string> */
    public static function abilities(): array
    {
        if (self::$user === null) {
            return [];
        }

        return FleetAbilities::normalize(self::$user['abilities'] ?? []);
    }

    /** @return list<string> */
    public static function effectiveAbilities(): array
    {
        return FleetAbilities::expand(self::abilities());
    }

    public static function can(string $ability): bool
    {
        return FleetAbilities::grants(self::abilities(), $ability);
    }

    public static function requireAbility(string $ability): void
    {
        if (! self::can($ability)) {
            throw new \RuntimeException('Forbidden: missing ability '.$ability, 403);
        }
    }

    public static function isBreakGlass(): bool
    {
        return self::$breakGlass;
    }

    /** Clear request auth state (tests only). */
    public static function resetForTests(): void
    {
        self::$user = null;
        self::$breakGlass = false;
    }
}
