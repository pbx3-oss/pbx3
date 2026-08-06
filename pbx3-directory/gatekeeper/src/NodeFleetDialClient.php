<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Gatekeeper → node fleet dialalias + commit (C2/C3).
 */
final class NodeFleetDialClient
{
    private Client $http;

    private string $fleetToken;

    public function __construct(?Client $http = null, ?string $fleetToken = null)
    {
        $this->fleetToken = $fleetToken ?? (getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '');
        $this->http = $http ?? new Client([
            'timeout' => 120,
            'http_errors' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function listDialAliases(string $apiBaseUrl, string $cluster): array
    {
        $decoded = $this->request('GET', rtrim($apiBaseUrl, '/').'/fleet/dialaliases', null, [
            'cluster' => $cluster,
        ]);
        $rows = $decoded['dialaliases'] ?? [];

        return is_array($rows) ? array_values(array_filter($rows, 'is_array')) : [];
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function upsertDialAlias(string $apiBaseUrl, array $body): array
    {
        return $this->request('PUT', rtrim($apiBaseUrl, '/').'/fleet/dialaliases', $body);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function deleteDialAlias(string $apiBaseUrl, array $body): array
    {
        return $this->request('DELETE', rtrim($apiBaseUrl, '/').'/fleet/dialaliases', $body);
    }

    /** @return array<string, mixed> */
    public function commit(string $apiBaseUrl): array
    {
        return $this->request('POST', rtrim($apiBaseUrl, '/').'/fleet/commit', []);
    }

    /**
     * @param  array<string, mixed>|null  $body
     * @param  array<string, string>|null  $query
     * @return array<string, mixed>
     */
    private function request(string $method, string $url, ?array $body, ?array $query = null): array
    {
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }
        $opts = [
            'headers' => [
                'Authorization' => 'Bearer '.$this->fleetToken,
                'Accept' => 'application/json',
            ],
        ];
        if ($query !== null) {
            $opts['query'] = $query;
        }
        if ($body !== null) {
            $opts['headers']['Content-Type'] = 'application/json';
            $opts['json'] = $body;
        }
        try {
            $res = $this->http->request($method, $url, $opts);
        } catch (GuzzleException $e) {
            throw new \RuntimeException("Node fleet HTTP {$method} {$url}: ".$e->getMessage(), 502, $e);
        }
        $code = $res->getStatusCode();
        $raw = (string) $res->getBody();
        $decoded = json_decode($raw, true);
        if ($code < 200 || $code >= 300) {
            $msg = is_array($decoded)
                ? (string) ($decoded['message'] ?? $decoded['error'] ?? $raw)
                : $raw;
            throw new \RuntimeException(
                $msg !== '' ? $msg : "Node fleet HTTP {$code}",
                $code >= 400 && $code < 600 ? $code : 502
            );
        }

        return is_array($decoded) ? $decoded : [];
    }
}
