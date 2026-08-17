<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\S3\S3Client;

/**
 * Shared S3 client for org/recordings buckets (Rule 9).
 * AWS is the default; Garage/R2/MinIO-class labs set AWS_ENDPOINT + path-style + static keys.
 */
final class S3ClientFactory
{
    public static function make(): S3Client
    {
        return new S3Client(self::config());
    }

    /**
     * @return array<string, mixed>
     */
    public static function config(): array
    {
        $region = trim((string) (getenv('AWS_DEFAULT_REGION') ?: ''));
        if ($region === '') {
            $region = 'us-east-1';
        }

        $config = [
            'version' => 'latest',
            'region' => $region,
        ];

        $endpoint = trim((string) (getenv('AWS_ENDPOINT') ?: ''));
        if ($endpoint !== '') {
            $config['endpoint'] = $endpoint;
            $config['use_path_style_endpoint'] = self::envBool('AWS_USE_PATH_STYLE_ENDPOINT', false);
        }

        $key = trim((string) (getenv('AWS_ACCESS_KEY_ID') ?: ''));
        $secret = trim((string) (getenv('AWS_SECRET_ACCESS_KEY') ?: ''));
        if ($key !== '' && $secret !== '') {
            $config['credentials'] = [
                'key' => $key,
                'secret' => $secret,
            ];
        }

        return $config;
    }

    public static function envBool(string $name, bool $default): bool
    {
        $raw = getenv($name);
        if ($raw === false || trim((string) $raw) === '') {
            return $default;
        }
        $v = strtolower(trim((string) $raw));

        return in_array($v, ['1', 'true', 'yes', 'on'], true);
    }
}
