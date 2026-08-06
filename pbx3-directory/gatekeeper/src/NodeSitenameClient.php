<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Push instance friendly Name (sitename) onto the node via fleet service token.
 *
 * @see pbx3/workingdocs/FLEET_NAMING_LOCK.md
 */
final class NodeSitenameClient
{
    private Client $http;

    private string $fleetToken;

    public function __construct(?Client $http = null, ?string $fleetToken = null)
    {
        $this->fleetToken = $fleetToken ?? (getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '');
        $this->http = $http ?? new Client([
            'timeout' => 30,
            'http_errors' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    public function putSitename(string $apiBaseUrl, string $sitename): void
    {
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }
        $base = rtrim($apiBaseUrl, '/');
        if ($base === '') {
            throw new \InvalidArgumentException('api_base_url required to sync sitename', 422);
        }
        $url = $base.'/fleet/sitename';
        try {
            $res = $this->http->request('PUT', $url, [
                'headers' => [
                    'Authorization' => 'Bearer '.$this->fleetToken,
                    'Accept' => 'application/json',
                    'Content-Type' => 'application/json',
                ],
                'json' => ['sitename' => $sitename],
            ]);
        } catch (GuzzleException $e) {
            throw new \RuntimeException('Node sitename HTTP error: '.$e->getMessage(), 502, $e);
        }
        $code = $res->getStatusCode();
        $raw = (string) $res->getBody();
        if ($code < 200 || $code >= 300) {
            $decoded = json_decode($raw, true);
            $msg = is_array($decoded)
                ? (string) ($decoded['message'] ?? $decoded['Error'] ?? $raw)
                : $raw;
            throw new \RuntimeException(
                $msg !== '' ? $msg : "Node sitename HTTP {$code}",
                $code >= 400 && $code < 600 ? $code : 502
            );
        }
    }
}
