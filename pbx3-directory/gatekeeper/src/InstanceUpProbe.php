<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Probe a live node's Laravel /up endpoint before catalog register (S10.2).
 */
final class InstanceUpProbe
{
    /**
     * Derive /up from api_base_url (…/api → …/up).
     */
    public static function upUrl(string $apiBaseUrl): string
    {
        $base = rtrim(trim($apiBaseUrl), '/');
        if ($base === '') {
            throw new \InvalidArgumentException('api_base_url required for up probe', 422);
        }
        if (str_ends_with($base, '/api')) {
            return substr($base, 0, -4).'/up';
        }

        return $base.'/up';
    }

    /**
     * GET /up; throw 422 on transport or non-2xx failure (does not write catalog).
     */
    public static function verify(string $apiBaseUrl, int $timeoutSeconds = 8): void
    {
        $url = self::upUrl($apiBaseUrl);
        $verifyTls = filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL);

        if (function_exists('curl_init')) {
            self::verifyWithCurl($url, $timeoutSeconds, $verifyTls);

            return;
        }

        $ctx = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => $timeoutSeconds,
                'ignore_errors' => true,
                'header' => "Accept: application/json\r\n",
            ],
            'ssl' => [
                'verify_peer' => $verifyTls,
                'verify_peer_name' => $verifyTls,
            ],
        ]);
        $body = @file_get_contents($url, false, $ctx);
        $status = 0;
        if (isset($http_response_header[0]) && preg_match('/\s(\d{3})\s/', $http_response_header[0], $m)) {
            $status = (int) $m[1];
        }
        if ($body === false || $status < 200 || $status >= 300) {
            throw new \RuntimeException(
                "Instance /up probe failed for {$url}".($status > 0 ? " (HTTP {$status})" : ' (unreachable)'),
                422
            );
        }
    }

    private static function verifyWithCurl(string $url, int $timeoutSeconds, bool $verifyTls): void
    {
        $ch = curl_init($url);
        if ($ch === false) {
            throw new \RuntimeException('curl_init failed for /up probe', 500);
        }
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT => $timeoutSeconds,
            CURLOPT_CONNECTTIMEOUT => min(5, $timeoutSeconds),
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
            CURLOPT_SSL_VERIFYPEER => $verifyTls,
            CURLOPT_SSL_VERIFYHOST => $verifyTls ? 2 : 0,
        ]);
        $body = curl_exec($ch);
        $errno = curl_errno($ch);
        $err = curl_error($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($errno !== 0 || $body === false) {
            throw new \RuntimeException("Instance /up probe failed for {$url}: {$err}", 422);
        }
        if ($status < 200 || $status >= 300) {
            throw new \RuntimeException("Instance /up probe failed for {$url} (HTTP {$status})", 422);
        }
    }
}
