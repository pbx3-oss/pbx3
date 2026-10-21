<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Fetch instance identity (KSUID / FQDN / sitename) from a home via fleet service token.
 *
 * Used by Fleet Register probe (#5m) so operators need not leave Fleet for globals.id.
 */
final class NodeIdentityClient
{
    private Client $http;

    private string $fleetToken;

    public function __construct(?Client $http = null, ?string $fleetToken = null)
    {
        $this->fleetToken = $fleetToken ?? (getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '');
        $this->http = $http ?? new Client([
            'timeout' => 15,
            'http_errors' => false,
            // Lab snakeoil :44300 — same as other node fleet clients when VERIFY=false.
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @return array{ok:bool,id:string,shortuid:string,fqdn:string,sitename:?string,api_base_url:string}
     */
    public function fetch(string $apiBaseUrl): array
    {
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }
        $base = rtrim($apiBaseUrl, '/');
        if ($base === '') {
            throw new \InvalidArgumentException('api_base_url required', 422);
        }
        // Accept https://host:44300/api or https://host:44300
        if (! str_ends_with($base, '/api')) {
            $base .= '/api';
        }
        $url = $base.'/fleet/identity';
        try {
            $res = $this->http->request('GET', $url, [
                'headers' => [
                    'Authorization' => 'Bearer '.$this->fleetToken,
                    'Accept' => 'application/json',
                ],
            ]);
        } catch (GuzzleException $e) {
            throw new \RuntimeException('Node identity HTTP error: '.$e->getMessage(), 502, $e);
        }
        $code = $res->getStatusCode();
        $raw = (string) $res->getBody();
        $decoded = json_decode($raw, true);
        if ($code < 200 || $code >= 300 || ! is_array($decoded)) {
            $msg = is_array($decoded)
                ? (string) ($decoded['message'] ?? $decoded['error'] ?? $raw)
                : $raw;
            throw new \RuntimeException(
                $msg !== '' ? $msg : "Node identity HTTP {$code}",
                $code >= 400 && $code < 600 ? $code : 502
            );
        }
        $id = trim((string) ($decoded['id'] ?? ''));
        $fqdn = trim((string) ($decoded['fqdn'] ?? ''));
        if ($id === '' || $fqdn === '') {
            throw new \RuntimeException('Node identity missing id or fqdn', 502);
        }
        $sitename = $decoded['sitename'] ?? null;
        if (is_string($sitename)) {
            $sitename = trim($sitename);
            if ($sitename === '') {
                $sitename = null;
            }
        } else {
            $sitename = null;
        }

        return [
            'ok' => true,
            'id' => $id,
            'shortuid' => trim((string) ($decoded['shortuid'] ?? '')),
            'fqdn' => $fqdn,
            'sitename' => $sitename,
            'api_base_url' => $base,
        ];
    }
}
