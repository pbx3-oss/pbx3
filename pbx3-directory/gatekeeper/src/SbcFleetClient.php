<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Outbound SbcFleetAdapter client (gatekeeper → pbx3sbc-admin /api/fleet/*).
 */
final class SbcFleetClient
{
    private Client $http;

    private string $fleetToken;

    private string $sbcApiBase;

    public function __construct(?Client $http = null)
    {
        $this->fleetToken = getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '';
        $this->sbcApiBase = rtrim(getenv('PBX3_SBC_ADMIN_API_URL') ?: '', '/');
        $this->http = $http ?? new Client([
            'timeout' => 60,
            'http_errors' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @return list<array{domain: string, setid: int}>
     */
    public function listDomains(): array
    {
        $payload = $this->get('/fleet/domains');
        $raw = $payload['domains'] ?? null;
        if (! is_array($raw)) {
            throw new \RuntimeException('SBC /fleet/domains missing domains array', 502);
        }

        $out = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $domain = isset($row['domain']) ? trim((string) $row['domain']) : '';
            if ($domain === '') {
                continue;
            }
            $out[] = [
                'domain' => $domain,
                'setid' => (int) ($row['setid'] ?? 0),
            ];
        }

        return $out;
    }

    /**
     * @return list<array{setid: int, destinations: int}>
     */
    public function listDispatcherSets(): array
    {
        $payload = $this->get('/fleet/dispatcher-sets');
        $raw = $payload['sets'] ?? null;
        if (! is_array($raw)) {
            throw new \RuntimeException('SBC /fleet/dispatcher-sets missing sets array', 502);
        }

        $out = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $setid = (int) ($row['setid'] ?? 0);
            if ($setid < 1) {
                continue;
            }
            $out[] = [
                'setid' => $setid,
                'destinations' => (int) ($row['destinations'] ?? 0),
            ];
        }

        return $out;
    }

    /**
     * Project tenant domain → dispatcher setid (adapter repointTenant).
     *
     * @return array<string, mixed>
     */
    public function repointTenant(string $tenantDomain, int $destDispatcherSetid): array
    {
        $tenantDomain = trim($tenantDomain);
        if ($tenantDomain === '' || $destDispatcherSetid < 1) {
            throw new \InvalidArgumentException('tenant_domain and dest_dispatcher_setid (>=1) required', 422);
        }

        return $this->post('/fleet/repoint', [
            'tenant_domain' => $tenantDomain,
            'dest_dispatcher_setid' => $destDispatcherSetid,
        ]);
    }

    /**
     * S10.5 — project catalog DID rows onto SBC inbound dr_rules.
     *
     * @param  list<array<string, mixed>>  $dids
     * @return array<string, mixed>
     */
    public function projectDids(array $dids, bool $dryRun = false, array $ensureTenants = []): array
    {
        return $this->post('/fleet/project-dids', [
            'dids' => $dids,
            'dry_run' => $dryRun,
            'ensure_tenants' => array_values($ensureTenants),
        ]);
    }

    /**
     * S10.5 — ensure domain row exists with setid.
     *
     * @return array<string, mixed>
     */
    public function registerDomain(string $domain, int $setid): array
    {
        $domain = strtolower(trim($domain));
        if ($domain === '' || $setid < 1) {
            throw new \InvalidArgumentException('domain and setid (>=1) required', 422);
        }

        return $this->post('/fleet/domains', [
            'domain' => $domain,
            'setid' => $setid,
        ]);
    }

    /**
     * S10.5 residue — create/update dispatcher set + Asterisk Peer for a node.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function provisionNode(array $body): array
    {
        return $this->post('/fleet/provision-node', $body);
    }

    /** @return array<string, mixed> */
    private function get(string $path): array
    {
        return $this->requestJson('GET', $path);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function post(string $path, array $body): array
    {
        return $this->requestJson('POST', $path, $body);
    }

    /**
     * @param  array<string, mixed>|null  $body
     * @return array<string, mixed>
     */
    private function requestJson(string $method, string $path, ?array $body = null): array
    {
        if ($this->sbcApiBase === '') {
            throw new \RuntimeException('PBX3_SBC_ADMIN_API_URL not set — cannot reach SBC adapter', 503);
        }
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }

        $url = $this->sbcApiBase.$path;
        $opts = [
            'headers' => [
                'Authorization' => 'Bearer '.$this->fleetToken,
                'Accept' => 'application/json',
            ],
        ];
        if ($body !== null) {
            $opts['headers']['Content-Type'] = 'application/json';
            $opts['json'] = $body;
        }

        try {
            $res = $this->http->request($method, $url, $opts);
        } catch (GuzzleException $e) {
            throw new \RuntimeException("HTTP {$method} {$url}: ".$e->getMessage(), 502);
        }

        $code = $res->getStatusCode();
        $decoded = json_decode((string) $res->getBody(), true);
        if ($code >= 400) {
            $msg = is_array($decoded)
                ? ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded))
                : (string) $res->getBody();
            throw new \RuntimeException(
                "HTTP {$method} {$url} → {$code}: {$msg}",
                $code >= 400 && $code < 600 ? $code : 502
            );
        }

        return is_array($decoded) ? $decoded : [];
    }
}
